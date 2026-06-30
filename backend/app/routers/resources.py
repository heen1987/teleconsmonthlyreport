import uuid
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.db.session import get_connection
from app.schemas import (
    CostCandidateRiskPromotionOut,
    ResourceAllocationCreate,
    ResourceAllocationOut,
    ResourceAllocationStatusUpdate,
    ResourceCalendarBlockCreate,
    ResourceCalendarBlockOut,
    ResourceConflictRiskPromotionOut,
    ResourceDemandOut,
    ResourceUsageCreate,
    ResourceUsageOut,
    ResourceUsageRecordOut,
    ProjectCostHandoffCreate,
    ProjectCostHandoffOut,
    ProjectCostHandoffSendDueRequest,
    ProjectCostHandoffStatusUpdate,
    ProjectCostCandidateOut,
    ProjectCostCandidateStatusUpdate,
    RiskOut,
    ResourceProfileAvailabilityOut,
    ResourceProfileCreate,
    ResourceProfileOut,
    ResourceUsageOverrunRiskPromotionOut,
    UnassignedResourceDemandRiskPromotionOut,
)
from app.services.auth_tokens import require_active_user
from app.services.erp_handoff import SENDABLE_HANDOFF_STATUSES, deliver_project_cost_handoff

router = APIRouter(prefix="/resources", tags=["resources"], dependencies=[Depends(require_active_user)])

PROFILE_RETURN_COLUMNS = """
    resource_id, resource_name, resource_type, capacity, unit, location,
    owner_user_id, status, created_by
"""

CALENDAR_BLOCK_RETURN_COLUMNS = """
    block_id, resource_id, project_id, starts_on, ends_on, block_type, reason,
    created_by
"""

ALLOCATION_RETURN_COLUMNS = """
    allocation_id, demand_id, project_id, resource_id, resource_name, resource_type,
    allocation_type, assignee_user_id, quantity, starts_on, ends_on, status,
    conflict_reason, created_by
"""

USAGE_RETURN_COLUMNS = """
    usage_id, allocation_id, project_id, resource_id, resource_name, resource_type,
    usage_date, quantity, unit, cost_amount, usage_status, note, created_by
"""

COST_RETURN_COLUMNS = """
    cost_id, project_id, source_type, source_id, cost_type, amount, currency,
    status, description, created_by, reviewed_by, reviewed_at, review_note
"""

HANDOFF_RETURN_COLUMNS = """
    handoff_id, cost_id, project_id, target_system, payload, status,
    external_reference, requested_by, created_at, completed_at,
    response_payload, response_note, response_received_by, delivery_mode,
    attempt_count, last_error, next_retry_at, last_attempted_at
"""


def _demand_status_for_allocation(allocation_type: str) -> str:
    if allocation_type == "reservation":
        return "reserved"
    return "assigned"


def _require_cost_reviewer(current_user: dict) -> None:
    if current_user["role"] not in {"admin", "pm", "finance"}:
        raise HTTPException(status_code=403, detail="Cost candidate review role required")


def _require_erp_handoff_user(current_user: dict) -> None:
    if current_user["role"] not in {"admin", "finance"}:
        raise HTTPException(status_code=403, detail="ERP handoff role required")


def _require_resource_calendar_manager(current_user: dict) -> None:
    if current_user["role"] not in {"admin", "pm", "resource_manager"}:
        raise HTTPException(status_code=403, detail="Resource calendar manager role required")


def _require_resource_risk_manager(current_user: dict) -> None:
    if current_user["role"] not in {"admin", "pm", "resource_manager"}:
        raise HTTPException(status_code=403, detail="Resource risk manager role required")


@router.post("/profiles", response_model=ResourceProfileOut)
def create_resource_profile(
    payload: ResourceProfileCreate,
    current_user: dict = Depends(require_active_user),
):
    resource_id = f"RSC-{uuid.uuid4().hex[:12]}"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                INSERT INTO resource_profiles
                    (
                        resource_id,
                        resource_name,
                        resource_type,
                        capacity,
                        unit,
                        location,
                        owner_user_id,
                        status,
                        created_by
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING {PROFILE_RETURN_COLUMNS}
                """,
                (
                    resource_id,
                    payload.resource_name,
                    payload.resource_type,
                    payload.capacity,
                    payload.unit,
                    payload.location,
                    payload.owner_user_id,
                    payload.status,
                    current_user["user_id"],
                ),
            )
            profile = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'create_resource_profile', 'resource_profiles', %s, %s)
                """,
                (
                    current_user["user_id"],
                    resource_id,
                    Jsonb(
                        {
                            "resource_name": payload.resource_name,
                            "resource_type": payload.resource_type,
                            "capacity": payload.capacity,
                            "status": payload.status,
                        }
                    ),
                ),
            )
    return profile


@router.get("/profiles", response_model=list[ResourceProfileOut])
def list_resource_profiles(resource_type: str | None = None, status: str | None = None):
    query = f"""
        SELECT {PROFILE_RETURN_COLUMNS}
        FROM resource_profiles
    """
    filters: list[str] = []
    params: list[Any] = []
    if resource_type:
        filters.append("resource_type = %s")
        params.append(resource_type)
    if status:
        filters.append("status = %s")
        params.append(status)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY resource_type ASC, resource_name ASC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.post("/profiles/{resource_id}/calendar-blocks", response_model=ResourceCalendarBlockOut)
def create_resource_calendar_block(
    resource_id: str,
    payload: ResourceCalendarBlockCreate,
    current_user: dict = Depends(require_active_user),
):
    _require_resource_calendar_manager(current_user)
    if payload.starts_on > payload.ends_on:
        raise HTTPException(status_code=422, detail="starts_on must be before or equal to ends_on")
    block_id = f"RCB-{uuid.uuid4().hex[:12]}"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT resource_id
                FROM resource_profiles
                WHERE resource_id = %s
                """,
                (resource_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="Resource profile not found")
            if payload.project_id:
                cursor.execute(
                    """
                    SELECT project_id
                    FROM projects
                    WHERE project_id = %s
                    """,
                    (payload.project_id,),
                )
                if cursor.fetchone() is None:
                    raise HTTPException(status_code=404, detail="Project not found")
            cursor.execute(
                f"""
                INSERT INTO resource_calendar_blocks
                    (
                        block_id,
                        resource_id,
                        project_id,
                        starts_on,
                        ends_on,
                        block_type,
                        reason,
                        created_by
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING {CALENDAR_BLOCK_RETURN_COLUMNS}
                """,
                (
                    block_id,
                    resource_id,
                    payload.project_id,
                    payload.starts_on,
                    payload.ends_on,
                    payload.block_type,
                    payload.reason,
                    current_user["user_id"],
                ),
            )
            block = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'create_resource_calendar_block', 'resource_calendar_blocks', %s, %s)
                """,
                (
                    current_user["user_id"],
                    block_id,
                    Jsonb(
                        {
                            "resource_id": resource_id,
                            "project_id": payload.project_id,
                            "starts_on": payload.starts_on.isoformat(),
                            "ends_on": payload.ends_on.isoformat(),
                            "block_type": payload.block_type,
                            "reason": payload.reason,
                        }
                    ),
                ),
            )
    return block


@router.get("/profiles/{resource_id}/calendar-blocks", response_model=list[ResourceCalendarBlockOut])
def list_resource_calendar_blocks(resource_id: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT resource_id
                FROM resource_profiles
                WHERE resource_id = %s
                """,
                (resource_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="Resource profile not found")
            cursor.execute(
                f"""
                SELECT {CALENDAR_BLOCK_RETURN_COLUMNS}
                FROM resource_calendar_blocks
                WHERE resource_id = %s
                ORDER BY starts_on DESC, created_at DESC
                """,
                (resource_id,),
            )
            rows = cursor.fetchall()
    return rows


@router.get("/profiles/availability", response_model=list[ResourceProfileAvailabilityOut])
def list_resource_profile_availability(
    starts_on: date,
    ends_on: date,
    resource_type: str | None = None,
):
    if starts_on > ends_on:
        raise HTTPException(status_code=422, detail="starts_on must be before or equal to ends_on")
    query = f"""
        SELECT
            {PROFILE_RETURN_COLUMNS},
            (
                status = 'active'
                AND blocker.allocation_id IS NULL
                AND calendar_blocker.block_id IS NULL
            ) AS is_available,
            blocker.allocation_id AS blocking_allocation_id,
            calendar_blocker.block_id AS blocking_calendar_block_id
        FROM resource_profiles
        LEFT JOIN LATERAL (
            SELECT ra.allocation_id
            FROM resource_allocations ra
            WHERE ra.status IN ('proposed', 'confirmed')
              AND (
                    ra.resource_id = resource_profiles.resource_id
                    OR (
                        ra.resource_id IS NULL
                        AND ra.resource_name = resource_profiles.resource_name
                    )
                  )
              AND COALESCE(ra.starts_on, DATE '0001-01-01') <= %s::date
              AND COALESCE(ra.ends_on, DATE '9999-12-31') >= %s::date
            ORDER BY ra.created_at ASC
            LIMIT 1
        ) blocker ON TRUE
        LEFT JOIN LATERAL (
            SELECT rcb.block_id
            FROM resource_calendar_blocks rcb
            WHERE rcb.resource_id = resource_profiles.resource_id
              AND rcb.starts_on <= %s::date
              AND rcb.ends_on >= %s::date
            ORDER BY rcb.starts_on ASC, rcb.created_at ASC
            LIMIT 1
        ) calendar_blocker ON TRUE
    """
    params: list[Any] = [ends_on, starts_on, ends_on, starts_on]
    if resource_type:
        query += " WHERE resource_type = %s"
        params.append(resource_type)
    query += " ORDER BY resource_type ASC, resource_name ASC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.get("/demands", response_model=list[ResourceDemandOut])
def list_resource_demands(project_id: str | None = None):
    query = """
        SELECT demand_id, project_id, source_meeting_id, source_analysis_id, name,
            resource_type, quantity, needed_from, needed_to, reason, demand_status
        FROM resource_demands
    """
    params: tuple[str, ...] = ()
    if project_id:
        query += " WHERE project_id = %s"
        params = (project_id,)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.post("/demands/unassigned-risks", response_model=UnassignedResourceDemandRiskPromotionOut)
def promote_unassigned_resource_demands_to_risks(
    project_id: str | None = None,
    due_within_days: int = Query(default=0, ge=0, le=365),
    include_unknown_dates: bool = False,
    limit: int = Query(default=50, ge=1, le=200),
    current_user: dict = Depends(require_active_user),
):
    _require_resource_risk_manager(current_user)
    date_filter = "needed_from <= CURRENT_DATE + %s::int"
    if include_unknown_dates:
        date_filter = "(needed_from IS NULL OR needed_from <= CURRENT_DATE + %s::int)"
    filters = ["demand_status = 'candidate'", date_filter]
    params: list[Any] = [due_within_days]
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    params.append(limit)

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT demand_id,
                    project_id,
                    source_meeting_id,
                    source_analysis_id,
                    name,
                    resource_type,
                    quantity,
                    needed_from,
                    needed_to,
                    reason,
                    demand_status
                FROM resource_demands
                WHERE {" AND ".join(filters)}
                ORDER BY COALESCE(needed_from, DATE '9999-12-31') ASC, created_at ASC
                LIMIT %s
                """,
                params,
            )
            demands = cursor.fetchall()

            created_risks: list[RiskOut] = []
            for demand in demands:
                demand_marker = [{"source_type": "resource_unassigned", "demand_id": demand["demand_id"]}]
                cursor.execute(
                    """
                    SELECT risk_id
                    FROM risks
                    WHERE project_id = %s
                      AND status IN ('candidate', 'open', 'active')
                      AND evidence_refs @> %s
                    LIMIT 1
                    """,
                    (demand["project_id"], Jsonb(demand_marker)),
                )
                if cursor.fetchone() is not None:
                    continue

                needed_from = demand["needed_from"]
                level = "high" if needed_from and needed_from < date.today() else "medium"
                date_text = needed_from.isoformat() if needed_from else "unknown"
                evidence = (
                    f"Resource demand {demand['demand_id']} remains unassigned "
                    f"with needed_from={date_text} and status={demand['demand_status']}."
                )
                evidence_refs = demand_marker + [
                    {
                        "resource_type": demand["resource_type"],
                        "quantity": float(demand["quantity"]) if demand["quantity"] is not None else None,
                        "needed_from": needed_from.isoformat() if needed_from else None,
                        "needed_to": demand["needed_to"].isoformat() if demand["needed_to"] else None,
                        "demand_status": demand["demand_status"],
                        "reason": demand["reason"],
                    }
                ]
                cursor.execute(
                    """
                    INSERT INTO risks
                        (
                            risk_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            title,
                            level,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            status
                        )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NULL, 'candidate')
                    RETURNING risk_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        level,
                        evidence,
                        evidence_refs,
                        ai_confidence,
                        status
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        demand["project_id"],
                        demand["source_meeting_id"],
                        demand["source_analysis_id"],
                        f"Unassigned resource demand: {demand['name']}",
                        level,
                        evidence,
                        Jsonb(evidence_refs),
                    ),
                )
                risk = cursor.fetchone()
                created_risks.append(RiskOut.model_validate(risk))
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'promote_unassigned_resource_demand_to_risk', 'risks', %s, %s)
                    """,
                    (
                        current_user["user_id"],
                        risk["risk_id"],
                        Jsonb(
                            {
                                "source_type": "resource_unassigned",
                                "demand_id": demand["demand_id"],
                                "needed_from": needed_from.isoformat() if needed_from else None,
                                "risk_level": level,
                            }
                        ),
                    ),
                )

    return UnassignedResourceDemandRiskPromotionOut(
        scanned_demands=len(demands),
        due_within_days=due_within_days,
        created_risks=created_risks,
    )


@router.patch("/demands/{demand_id}/status", response_model=ResourceDemandOut)
def update_resource_demand_status(demand_id: str, status: str):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                UPDATE resource_demands
                SET demand_status = %s
                WHERE demand_id = %s
                RETURNING demand_id, project_id, source_meeting_id, source_analysis_id, name,
                    resource_type, quantity, needed_from, needed_to, reason, demand_status
                """,
                (status, demand_id),
            )
            row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Resource demand not found")
    return row


@router.post("/demands/{demand_id}/allocations", response_model=ResourceAllocationOut)
def create_resource_allocation(
    demand_id: str,
    payload: ResourceAllocationCreate,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT demand_id, project_id, name, resource_type, quantity, needed_from, needed_to
                FROM resource_demands
                WHERE demand_id = %s
                """,
                (demand_id,),
            )
            demand = cursor.fetchone()
            if demand is None:
                raise HTTPException(status_code=404, detail="Resource demand not found")

            profile = None
            if payload.resource_id:
                cursor.execute(
                    """
                    SELECT resource_id, resource_name, resource_type, capacity, status
                    FROM resource_profiles
                    WHERE resource_id = %s
                    """,
                    (payload.resource_id,),
                )
                profile = cursor.fetchone()
                if profile is None:
                    raise HTTPException(status_code=404, detail="Resource profile not found")
                if profile["status"] != "active":
                    raise HTTPException(status_code=409, detail="Resource profile is not active")
                if demand["resource_type"] != "other" and profile["resource_type"] != demand["resource_type"]:
                    raise HTTPException(status_code=409, detail="Resource type does not match demand")

            effective_resource_id = profile["resource_id"] if profile else None
            effective_resource_name = profile["resource_name"] if profile else payload.resource_name
            effective_resource_type = profile["resource_type"] if profile else demand["resource_type"]
            if not effective_resource_name:
                raise HTTPException(status_code=422, detail="resource_id or resource_name is required")

            starts_on = payload.starts_on or demand["needed_from"]
            ends_on = payload.ends_on or demand["needed_to"]
            if starts_on and ends_on and starts_on > ends_on:
                raise HTTPException(status_code=422, detail="starts_on must be before or equal to ends_on")

            quantity = payload.quantity if payload.quantity is not None else demand["quantity"]
            cursor.execute(
                """
                SELECT allocation_id
                FROM resource_allocations
                WHERE status IN ('proposed', 'confirmed')
                  AND (
                        (
                            %s::text IS NOT NULL
                            AND (
                                resource_id = %s
                                OR (resource_id IS NULL AND resource_name = %s)
                            )
                        )
                        OR (
                            %s::text IS NULL
                            AND resource_name = %s
                        )
                      )
                  AND COALESCE(starts_on, DATE '0001-01-01') <= COALESCE(%s::date, DATE '9999-12-31')
                  AND COALESCE(ends_on, DATE '9999-12-31') >= COALESCE(%s::date, DATE '0001-01-01')
                ORDER BY created_at ASC
                LIMIT 1
                """,
                (
                    effective_resource_id,
                    effective_resource_id,
                    effective_resource_name,
                    effective_resource_id,
                    effective_resource_name,
                    ends_on,
                    starts_on,
                ),
            )
            conflict = cursor.fetchone()
            allocation_status = "conflict" if conflict else "proposed"
            conflict_reason = f"overlaps:{conflict['allocation_id']}" if conflict else None
            allocation_id = f"RAL-{uuid.uuid4().hex[:12]}"
            cursor.execute(
                f"""
                INSERT INTO resource_allocations
                    (
                        allocation_id,
                        demand_id,
                        project_id,
                        resource_id,
                        resource_name,
                        resource_type,
                        allocation_type,
                        assignee_user_id,
                        quantity,
                        starts_on,
                        ends_on,
                        status,
                        conflict_reason,
                        created_by
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING {ALLOCATION_RETURN_COLUMNS}
                """,
                (
                    allocation_id,
                    demand_id,
                    demand["project_id"],
                    effective_resource_id,
                    effective_resource_name,
                    effective_resource_type,
                    payload.allocation_type,
                    payload.assignee_user_id,
                    quantity,
                    starts_on,
                    ends_on,
                    allocation_status,
                    conflict_reason,
                    current_user["user_id"],
                ),
            )
            allocation = cursor.fetchone()
            demand_status = (
                "conflict"
                if allocation_status == "conflict"
                else _demand_status_for_allocation(payload.allocation_type)
            )
            cursor.execute(
                """
                UPDATE resource_demands
                SET demand_status = %s
                WHERE demand_id = %s
                """,
                (demand_status, demand_id),
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'create_resource_allocation', 'resource_allocations', %s, %s)
                """,
                (
                    current_user["user_id"],
                    allocation_id,
                    Jsonb(
                        {
                            "demand_id": demand_id,
                            "status": allocation_status,
                            "allocation_type": payload.allocation_type,
                            "resource_id": effective_resource_id,
                            "resource_name": effective_resource_name,
                            "conflict_reason": conflict_reason,
                        }
                    ),
                ),
            )
    return allocation


@router.get("/allocations", response_model=list[ResourceAllocationOut])
def list_resource_allocations(project_id: str | None = None, status: str | None = None):
    query = f"""
        SELECT {ALLOCATION_RETURN_COLUMNS}
        FROM resource_allocations
    """
    filters: list[str] = []
    params: list[Any] = []
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    if status:
        filters.append("status = %s")
        params.append(status)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.post("/allocations/conflict-risks", response_model=ResourceConflictRiskPromotionOut)
def promote_resource_conflicts_to_risks(
    project_id: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    current_user: dict = Depends(require_active_user),
):
    _require_resource_risk_manager(current_user)
    filters = ["status = 'conflict'"]
    params: list[Any] = []
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    params.append(limit)

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {ALLOCATION_RETURN_COLUMNS}
                FROM resource_allocations
                WHERE {" AND ".join(filters)}
                ORDER BY COALESCE(starts_on, DATE '9999-12-31') ASC, created_at DESC
                LIMIT %s
                """,
                params,
            )
            conflicts = cursor.fetchall()

            created_risks: list[RiskOut] = []
            for allocation in conflicts:
                conflict_marker = [
                    {"source_type": "resource_conflict", "allocation_id": allocation["allocation_id"]}
                ]
                cursor.execute(
                    """
                    SELECT risk_id
                    FROM risks
                    WHERE project_id = %s
                      AND status IN ('candidate', 'open', 'active')
                      AND evidence_refs @> %s
                    LIMIT 1
                    """,
                    (allocation["project_id"], Jsonb(conflict_marker)),
                )
                if cursor.fetchone() is not None:
                    continue

                starts_on = allocation["starts_on"]
                ends_on = allocation["ends_on"]
                level = "high" if starts_on and starts_on <= date.today() else "medium"
                period = "unbounded"
                if starts_on or ends_on:
                    period = (
                        f"{starts_on.isoformat() if starts_on else 'open'}"
                        f"..{ends_on.isoformat() if ends_on else 'open'}"
                    )
                evidence = (
                    f"Resource allocation {allocation['allocation_id']} is in conflict "
                    f"for resource={allocation['resource_name']} period={period} "
                    f"reason={allocation['conflict_reason']}."
                )
                evidence_refs = conflict_marker + [
                    {
                        "demand_id": allocation["demand_id"],
                        "resource_id": allocation["resource_id"],
                        "resource_name": allocation["resource_name"],
                        "resource_type": allocation["resource_type"],
                        "allocation_type": allocation["allocation_type"],
                        "starts_on": starts_on.isoformat() if starts_on else None,
                        "ends_on": ends_on.isoformat() if ends_on else None,
                        "conflict_reason": allocation["conflict_reason"],
                    }
                ]
                cursor.execute(
                    """
                    INSERT INTO risks
                        (
                            risk_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            title,
                            level,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            status
                        )
                    VALUES (%s, %s, NULL, NULL, %s, %s, %s, %s, NULL, 'candidate')
                    RETURNING risk_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        level,
                        evidence,
                        evidence_refs,
                        ai_confidence,
                        status
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        allocation["project_id"],
                        f"Resource conflict: {allocation['resource_name']}",
                        level,
                        evidence,
                        Jsonb(evidence_refs),
                    ),
                )
                risk = cursor.fetchone()
                created_risks.append(RiskOut.model_validate(risk))
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'promote_resource_conflict_to_risk', 'risks', %s, %s)
                    """,
                    (
                        current_user["user_id"],
                        risk["risk_id"],
                        Jsonb(
                            {
                                "source_type": "resource_conflict",
                                "allocation_id": allocation["allocation_id"],
                                "demand_id": allocation["demand_id"],
                                "conflict_reason": allocation["conflict_reason"],
                                "risk_level": level,
                            }
                        ),
                    ),
                )

    return ResourceConflictRiskPromotionOut(
        scanned_conflicts=len(conflicts),
        created_risks=created_risks,
    )


@router.patch("/allocations/{allocation_id}/status", response_model=ResourceAllocationOut)
def update_resource_allocation_status(
    allocation_id: str,
    payload: ResourceAllocationStatusUpdate,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {ALLOCATION_RETURN_COLUMNS}
                FROM resource_allocations
                WHERE allocation_id = %s
                """,
                (allocation_id,),
            )
            before = cursor.fetchone()
            if before is None:
                raise HTTPException(status_code=404, detail="Resource allocation not found")
            if before["status"] == "conflict" and payload.status in {"proposed", "confirmed"}:
                raise HTTPException(status_code=409, detail="Conflict allocation must be cancelled first")

            cursor.execute(
                f"""
                UPDATE resource_allocations
                SET status = %s, updated_at = now()
                WHERE allocation_id = %s
                RETURNING {ALLOCATION_RETURN_COLUMNS}
                """,
                (payload.status, allocation_id),
            )
            allocation = cursor.fetchone()
            demand_status = (
                "candidate"
                if payload.status in {"released", "cancelled"}
                else _demand_status_for_allocation(allocation["allocation_type"])
            )
            cursor.execute(
                """
                UPDATE resource_demands
                SET demand_status = %s
                WHERE demand_id = %s
                """,
                (demand_status, allocation["demand_id"]),
            )
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'update_resource_allocation_status', 'resource_allocations', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    allocation_id,
                    Jsonb({"status": before["status"]}),
                    Jsonb({"status": payload.status, "demand_status": demand_status}),
                ),
            )
    return allocation


@router.post("/allocations/{allocation_id}/usage", response_model=ResourceUsageRecordOut)
def record_resource_usage(
    allocation_id: str,
    payload: ResourceUsageCreate,
    current_user: dict = Depends(require_active_user),
):
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {ALLOCATION_RETURN_COLUMNS}
                FROM resource_allocations
                WHERE allocation_id = %s
                """,
                (allocation_id,),
            )
            allocation = cursor.fetchone()
            if allocation is None:
                raise HTTPException(status_code=404, detail="Resource allocation not found")
            if allocation["status"] in {"conflict", "cancelled"}:
                raise HTTPException(status_code=409, detail="Only active allocation can record usage")

            usage_id = f"RUS-{uuid.uuid4().hex[:12]}"
            cursor.execute(
                f"""
                INSERT INTO resource_usage_entries
                    (
                        usage_id,
                        allocation_id,
                        project_id,
                        resource_id,
                        resource_name,
                        resource_type,
                        usage_date,
                        quantity,
                        unit,
                        cost_amount,
                        note,
                        created_by
                    )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING {USAGE_RETURN_COLUMNS}
                """,
                (
                    usage_id,
                    allocation_id,
                    allocation["project_id"],
                    allocation["resource_id"],
                    allocation["resource_name"],
                    allocation["resource_type"],
                    payload.usage_date,
                    payload.quantity,
                    payload.unit,
                    payload.cost_amount,
                    payload.note,
                    current_user["user_id"],
                ),
            )
            usage = cursor.fetchone()

            cost_candidate = None
            if payload.cost_amount is not None:
                cost_id = f"CST-{uuid.uuid4().hex[:12]}"
                cursor.execute(
                    f"""
                    INSERT INTO project_cost_candidates
                        (
                            cost_id,
                            project_id,
                            source_type,
                            source_id,
                            cost_type,
                            amount,
                            currency,
                            status,
                            description,
                            created_by
                        )
                    VALUES (%s, %s, 'resource_usage', %s, 'resource_usage', %s, 'KRW', 'candidate', %s, %s)
                    RETURNING {COST_RETURN_COLUMNS}
                    """,
                    (
                        cost_id,
                        allocation["project_id"],
                        usage_id,
                        payload.cost_amount,
                        payload.note or f"{allocation['resource_name']} usage",
                        current_user["user_id"],
                    ),
                )
                cost_candidate = cursor.fetchone()

            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'record_resource_usage', 'resource_usage_entries', %s, %s)
                """,
                (
                    current_user["user_id"],
                    usage_id,
                    Jsonb(
                        {
                            "allocation_id": allocation_id,
                            "project_id": allocation["project_id"],
                            "quantity": payload.quantity,
                            "unit": payload.unit,
                            "cost_amount": payload.cost_amount,
                            "cost_candidate_id": cost_candidate["cost_id"] if cost_candidate else None,
                        }
                    ),
                ),
            )
    return ResourceUsageRecordOut(usage=usage, cost_candidate=cost_candidate)


@router.get("/usage", response_model=list[ResourceUsageOut])
def list_resource_usage(project_id: str | None = None, allocation_id: str | None = None):
    query = f"""
        SELECT {USAGE_RETURN_COLUMNS}
        FROM resource_usage_entries
    """
    filters: list[str] = []
    params: list[Any] = []
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    if allocation_id:
        filters.append("allocation_id = %s")
        params.append(allocation_id)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY usage_date DESC, created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.post("/usage/overrun-risks", response_model=ResourceUsageOverrunRiskPromotionOut)
def promote_resource_usage_overruns_to_risks(
    project_id: str | None = None,
    threshold_ratio: float = Query(default=1.0, ge=1.0, le=100.0),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: dict = Depends(require_active_user),
):
    _require_resource_risk_manager(current_user)
    filters = [
        "ra.quantity IS NOT NULL",
        "rue.quantity > ra.quantity * %s",
        "rue.usage_status NOT IN ('cancelled', 'rejected')",
    ]
    params: list[Any] = [threshold_ratio]
    if project_id:
        filters.append("rue.project_id = %s")
        params.append(project_id)
    params.append(limit)

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT rue.usage_id,
                    rue.allocation_id,
                    rue.project_id,
                    rue.resource_id,
                    rue.resource_name,
                    rue.resource_type,
                    rue.usage_date,
                    rue.quantity AS usage_quantity,
                    rue.unit,
                    rue.cost_amount,
                    rue.usage_status,
                    rue.note,
                    ra.quantity AS allocation_quantity,
                    ra.allocation_type,
                    ra.starts_on,
                    ra.ends_on
                FROM resource_usage_entries rue
                JOIN resource_allocations ra ON ra.allocation_id = rue.allocation_id
                WHERE {" AND ".join(filters)}
                ORDER BY rue.usage_date DESC, rue.created_at DESC
                LIMIT %s
                """,
                params,
            )
            usage_entries = cursor.fetchall()

            created_risks: list[RiskOut] = []
            for usage in usage_entries:
                usage_marker = [{"source_type": "resource_usage_overrun", "usage_id": usage["usage_id"]}]
                cursor.execute(
                    """
                    SELECT risk_id
                    FROM risks
                    WHERE project_id = %s
                      AND status IN ('candidate', 'open', 'active')
                      AND evidence_refs @> %s
                    LIMIT 1
                    """,
                    (usage["project_id"], Jsonb(usage_marker)),
                )
                if cursor.fetchone() is not None:
                    continue

                usage_quantity = float(usage["usage_quantity"])
                allocation_quantity = float(usage["allocation_quantity"])
                ratio = usage_quantity / allocation_quantity if allocation_quantity > 0 else 0
                level = "high" if ratio >= 1.5 else "medium"
                evidence = (
                    f"Resource usage {usage['usage_id']} quantity={usage_quantity:g} {usage['unit']} "
                    f"exceeded allocation quantity={allocation_quantity:g} threshold_ratio={threshold_ratio:g}."
                )
                evidence_refs = usage_marker + [
                    {
                        "allocation_id": usage["allocation_id"],
                        "resource_id": usage["resource_id"],
                        "resource_name": usage["resource_name"],
                        "resource_type": usage["resource_type"],
                        "allocation_type": usage["allocation_type"],
                        "usage_date": usage["usage_date"].isoformat() if usage["usage_date"] else None,
                        "usage_quantity": usage_quantity,
                        "allocation_quantity": allocation_quantity,
                        "threshold_ratio": threshold_ratio,
                        "ratio": ratio,
                        "unit": usage["unit"],
                        "usage_status": usage["usage_status"],
                    }
                ]
                cursor.execute(
                    """
                    INSERT INTO risks
                        (
                            risk_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            title,
                            level,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            status
                        )
                    VALUES (%s, %s, NULL, NULL, %s, %s, %s, %s, NULL, 'candidate')
                    RETURNING risk_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        level,
                        evidence,
                        evidence_refs,
                        ai_confidence,
                        status
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        usage["project_id"],
                        f"Resource usage overrun: {usage['resource_name']}",
                        level,
                        evidence,
                        Jsonb(evidence_refs),
                    ),
                )
                risk = cursor.fetchone()
                created_risks.append(RiskOut.model_validate(risk))
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'promote_resource_usage_overrun_to_risk', 'risks', %s, %s)
                    """,
                    (
                        current_user["user_id"],
                        risk["risk_id"],
                        Jsonb(
                            {
                                "source_type": "resource_usage_overrun",
                                "usage_id": usage["usage_id"],
                                "allocation_id": usage["allocation_id"],
                                "usage_quantity": usage_quantity,
                                "allocation_quantity": allocation_quantity,
                                "ratio": ratio,
                                "risk_level": level,
                            }
                        ),
                    ),
                )

    return ResourceUsageOverrunRiskPromotionOut(
        scanned_usage_entries=len(usage_entries),
        threshold_ratio=threshold_ratio,
        created_risks=created_risks,
    )


@router.get("/cost-candidates", response_model=list[ProjectCostCandidateOut])
def list_project_cost_candidates(project_id: str | None = None, status: str | None = None):
    query = f"""
        SELECT {COST_RETURN_COLUMNS}
        FROM project_cost_candidates
    """
    filters: list[str] = []
    params: list[Any] = []
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    if status:
        filters.append("status = %s")
        params.append(status)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows


@router.patch("/cost-candidates/{cost_id}/status", response_model=ProjectCostCandidateOut)
def update_project_cost_candidate_status(
    cost_id: str,
    payload: ProjectCostCandidateStatusUpdate,
    current_user: dict = Depends(require_active_user),
):
    _require_cost_reviewer(current_user)
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {COST_RETURN_COLUMNS}
                FROM project_cost_candidates
                WHERE cost_id = %s
                """,
                (cost_id,),
            )
            before = cursor.fetchone()
            if before is None:
                raise HTTPException(status_code=404, detail="Cost candidate not found")
            if before["status"] != "candidate":
                raise HTTPException(status_code=409, detail="Only candidate cost can be reviewed")

            cursor.execute(
                f"""
                UPDATE project_cost_candidates
                SET
                    status = %s,
                    reviewed_by = %s,
                    reviewed_at = now(),
                    review_note = %s
                WHERE cost_id = %s
                RETURNING {COST_RETURN_COLUMNS}
                """,
                (
                    payload.status,
                    current_user["user_id"],
                    payload.review_note,
                    cost_id,
                ),
            )
            candidate = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'review_project_cost_candidate', 'project_cost_candidates', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    cost_id,
                    Jsonb(
                        {
                            "status": before["status"],
                            "reviewed_by": before["reviewed_by"],
                            "reviewed_at": before["reviewed_at"].isoformat() if before["reviewed_at"] else None,
                            "review_note": before["review_note"],
                        }
                    ),
                    Jsonb(
                        {
                            "status": candidate["status"],
                            "reviewed_by": candidate["reviewed_by"],
                            "reviewed_at": candidate["reviewed_at"].isoformat() if candidate["reviewed_at"] else None,
                            "review_note": candidate["review_note"],
                        }
                    ),
                ),
            )
    return candidate


@router.post("/cost-candidates/overrun-risks", response_model=CostCandidateRiskPromotionOut)
def promote_cost_candidates_to_risks(
    project_id: str | None = None,
    threshold_amount: float = Query(default=1_000_000, ge=0),
    currency: str = Query(default="KRW", min_length=1, max_length=8),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: dict = Depends(require_active_user),
):
    _require_cost_reviewer(current_user)
    normalized_currency = currency.upper()
    filters = [
        "amount >= %s",
        "currency = %s",
        "status IN ('candidate', 'approved')",
    ]
    params: list[Any] = [threshold_amount, normalized_currency]
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    params.append(limit)

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {COST_RETURN_COLUMNS}
                FROM project_cost_candidates
                WHERE {" AND ".join(filters)}
                ORDER BY amount DESC, created_at DESC
                LIMIT %s
                """,
                params,
            )
            candidates = cursor.fetchall()

            created_risks: list[RiskOut] = []
            for candidate in candidates:
                cost_marker = [{"source_type": "cost_threshold", "cost_id": candidate["cost_id"]}]
                cursor.execute(
                    """
                    SELECT risk_id
                    FROM risks
                    WHERE project_id = %s
                      AND status IN ('candidate', 'open', 'active')
                      AND evidence_refs @> %s
                    LIMIT 1
                    """,
                    (candidate["project_id"], Jsonb(cost_marker)),
                )
                if cursor.fetchone() is not None:
                    continue

                amount = float(candidate["amount"])
                level = "high" if threshold_amount > 0 and amount >= threshold_amount * 2 else "medium"
                label = candidate["description"] or candidate["cost_type"]
                evidence = (
                    f"Cost candidate {candidate['cost_id']} amount={amount:g} {candidate['currency']} "
                    f"exceeded threshold={threshold_amount:g} {normalized_currency}."
                )
                evidence_refs = cost_marker + [
                    {
                        "source_type": candidate["source_type"],
                        "source_id": candidate["source_id"],
                        "cost_type": candidate["cost_type"],
                        "amount": amount,
                        "currency": candidate["currency"],
                        "threshold_amount": threshold_amount,
                        "status": candidate["status"],
                    }
                ]
                cursor.execute(
                    """
                    INSERT INTO risks
                        (
                            risk_id,
                            project_id,
                            source_meeting_id,
                            source_analysis_id,
                            title,
                            level,
                            evidence,
                            evidence_refs,
                            ai_confidence,
                            status
                        )
                    VALUES (%s, %s, NULL, NULL, %s, %s, %s, %s, NULL, 'candidate')
                    RETURNING risk_id,
                        project_id,
                        source_meeting_id,
                        source_analysis_id,
                        title,
                        level,
                        evidence,
                        evidence_refs,
                        ai_confidence,
                        status
                    """,
                    (
                        f"RSK-{uuid.uuid4().hex[:12]}",
                        candidate["project_id"],
                        f"Cost threshold exceeded: {label}",
                        level,
                        evidence,
                        Jsonb(evidence_refs),
                    ),
                )
                risk = cursor.fetchone()
                created_risks.append(RiskOut.model_validate(risk))
                cursor.execute(
                    """
                    INSERT INTO audit_logs
                        (actor_user_id, action_type, target_table, target_id, after_value)
                    VALUES (%s, 'promote_cost_candidate_to_risk', 'risks', %s, %s)
                    """,
                    (
                        current_user["user_id"],
                        risk["risk_id"],
                        Jsonb(
                            {
                                "source_type": "cost_threshold",
                                "cost_id": candidate["cost_id"],
                                "amount": amount,
                                "currency": candidate["currency"],
                                "threshold_amount": threshold_amount,
                                "risk_level": level,
                            }
                        ),
                    ),
                )

    return CostCandidateRiskPromotionOut(
        scanned_cost_candidates=len(candidates),
        threshold_amount=threshold_amount,
        currency=normalized_currency,
        created_risks=created_risks,
    )


@router.post("/cost-candidates/{cost_id}/erp-handoff", response_model=ProjectCostHandoffOut)
def create_project_cost_handoff(
    cost_id: str,
    payload: ProjectCostHandoffCreate | None = None,
    current_user: dict = Depends(require_active_user),
):
    _require_erp_handoff_user(current_user)
    handoff_request = payload or ProjectCostHandoffCreate()
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {COST_RETURN_COLUMNS}
                FROM project_cost_candidates
                WHERE cost_id = %s
                """,
                (cost_id,),
            )
            candidate = cursor.fetchone()
            if candidate is None:
                raise HTTPException(status_code=404, detail="Cost candidate not found")
            if candidate["status"] != "approved":
                raise HTTPException(status_code=409, detail="Only approved cost can be handed off")

            cursor.execute(
                f"""
                SELECT {HANDOFF_RETURN_COLUMNS}
                FROM project_cost_handoffs
                WHERE cost_id = %s
                  AND target_system = %s
                """,
                (cost_id, handoff_request.target_system),
            )
            existing = cursor.fetchone()
            if existing is not None:
                return existing

            handoff_id = f"PCH-{uuid.uuid4().hex[:12]}"
            handoff_payload = {
                "project_id": candidate["project_id"],
                "cost_id": candidate["cost_id"],
                "source_type": candidate["source_type"],
                "source_id": candidate["source_id"],
                "cost_type": candidate["cost_type"],
                "amount": float(candidate["amount"]),
                "currency": candidate["currency"],
                "description": candidate["description"],
                "approved_by": candidate["reviewed_by"],
                "approved_at": candidate["reviewed_at"].isoformat() if candidate["reviewed_at"] else None,
                "approval_note": candidate["review_note"],
                "ledger_boundary": "external_erp_reference_only",
            }
            cursor.execute(
                f"""
                INSERT INTO project_cost_handoffs
                    (
                        handoff_id,
                        cost_id,
                        project_id,
                        target_system,
                        payload,
                        status,
                        external_reference,
                        requested_by
                    )
                VALUES (%s, %s, %s, %s, %s, 'queued', %s, %s)
                RETURNING {HANDOFF_RETURN_COLUMNS}
                """,
                (
                    handoff_id,
                    cost_id,
                    candidate["project_id"],
                    handoff_request.target_system,
                    Jsonb(handoff_payload),
                    handoff_request.external_reference,
                    current_user["user_id"],
                ),
            )
            handoff = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, after_value)
                VALUES (%s, 'create_project_cost_handoff', 'project_cost_handoffs', %s, %s)
                """,
                (
                    current_user["user_id"],
                    handoff_id,
                    Jsonb(
                        {
                            "cost_id": cost_id,
                            "project_id": candidate["project_id"],
                            "target_system": handoff_request.target_system,
                            "status": handoff["status"],
                            "external_reference": handoff_request.external_reference,
                        }
                    ),
                ),
            )
    return handoff


@router.post("/cost-handoffs/send-due", response_model=list[ProjectCostHandoffOut])
def send_due_project_cost_handoffs(
    payload: ProjectCostHandoffSendDueRequest | None = None,
    current_user: dict = Depends(require_active_user),
):
    _require_erp_handoff_user(current_user)
    request = payload or ProjectCostHandoffSendDueRequest()
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {HANDOFF_RETURN_COLUMNS}
                FROM project_cost_handoffs
                WHERE status = 'queued'
                   OR (
                        status = 'retry_wait'
                        AND next_retry_at IS NOT NULL
                        AND next_retry_at <= now()
                      )
                ORDER BY
                    CASE WHEN status = 'queued' THEN 0 ELSE 1 END,
                    COALESCE(next_retry_at, created_at) ASC,
                    created_at ASC
                LIMIT %s
                FOR UPDATE SKIP LOCKED
                """,
                (request.limit,),
            )
            rows = cursor.fetchall()
            return [deliver_project_cost_handoff(cursor, row) for row in rows]


@router.post("/cost-handoffs/{handoff_id}/send", response_model=ProjectCostHandoffOut)
def send_project_cost_handoff(
    handoff_id: str,
    current_user: dict = Depends(require_active_user),
):
    _require_erp_handoff_user(current_user)
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {HANDOFF_RETURN_COLUMNS}
                FROM project_cost_handoffs
                WHERE handoff_id = %s
                FOR UPDATE
                """,
                (handoff_id,),
            )
            handoff = cursor.fetchone()
            if handoff is None:
                raise HTTPException(status_code=404, detail="Cost handoff not found")
            if handoff["status"] in {"accepted", "rejected", "failed"}:
                raise HTTPException(status_code=409, detail="Completed cost handoff cannot be sent")
            if handoff["status"] not in SENDABLE_HANDOFF_STATUSES:
                raise HTTPException(status_code=409, detail="Only queued or retry_wait cost handoff can be sent")
            return deliver_project_cost_handoff(cursor, handoff)


@router.patch("/cost-handoffs/{handoff_id}/status", response_model=ProjectCostHandoffOut)
def update_project_cost_handoff_status(
    handoff_id: str,
    payload: ProjectCostHandoffStatusUpdate,
    current_user: dict = Depends(require_active_user),
):
    _require_erp_handoff_user(current_user)
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                f"""
                SELECT {HANDOFF_RETURN_COLUMNS}
                FROM project_cost_handoffs
                WHERE handoff_id = %s
                """,
                (handoff_id,),
            )
            before = cursor.fetchone()
            if before is None:
                raise HTTPException(status_code=404, detail="Cost handoff not found")
            if before["status"] in {"accepted", "rejected", "failed"}:
                raise HTTPException(status_code=409, detail="Completed cost handoff cannot be changed")

            next_external_reference = payload.external_reference or before["external_reference"]
            cursor.execute(
                f"""
                UPDATE project_cost_handoffs
                SET
                    status = %s,
                    external_reference = %s,
                    completed_at = now(),
                    response_payload = %s,
                    response_note = %s,
                    response_received_by = %s
                WHERE handoff_id = %s
                RETURNING {HANDOFF_RETURN_COLUMNS}
                """,
                (
                    payload.status,
                    next_external_reference,
                    Jsonb(payload.response_payload),
                    payload.response_note,
                    current_user["user_id"],
                    handoff_id,
                ),
            )
            handoff = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO audit_logs
                    (actor_user_id, action_type, target_table, target_id, before_value, after_value)
                VALUES (%s, 'reconcile_project_cost_handoff', 'project_cost_handoffs', %s, %s, %s)
                """,
                (
                    current_user["user_id"],
                    handoff_id,
                    Jsonb(
                        {
                            "status": before["status"],
                            "external_reference": before["external_reference"],
                            "completed_at": before["completed_at"].isoformat() if before["completed_at"] else None,
                        }
                    ),
                    Jsonb(
                        {
                            "status": handoff["status"],
                            "external_reference": handoff["external_reference"],
                            "completed_at": handoff["completed_at"].isoformat() if handoff["completed_at"] else None,
                            "response_note": handoff["response_note"],
                        }
                    ),
                ),
            )
    return handoff


@router.get("/cost-handoffs", response_model=list[ProjectCostHandoffOut])
def list_project_cost_handoffs(
    project_id: str | None = None,
    status: str | None = None,
    target_system: str | None = None,
):
    query = f"""
        SELECT {HANDOFF_RETURN_COLUMNS}
        FROM project_cost_handoffs
    """
    filters: list[str] = []
    params: list[Any] = []
    if project_id:
        filters.append("project_id = %s")
        params.append(project_id)
    if status:
        filters.append("status = %s")
        params.append(status)
    if target_system:
        filters.append("target_system = %s")
        params.append(target_system)
    if filters:
        query += " WHERE " + " AND ".join(filters)
    query += " ORDER BY created_at DESC"
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()
    return rows
