from __future__ import annotations

from fastapi import HTTPException


def is_admin(current_user: dict) -> bool:
    return current_user.get("role") == "admin"


def user_can_access_project(cursor, project_id: str, current_user: dict) -> bool:
    if is_admin(current_user):
        return True
    user_id = current_user["user_id"]
    cursor.execute(
        """
        SELECT 1
        FROM projects p
        WHERE p.project_id = %s
          AND (
            p.pm_user_id = %s
            OR EXISTS (
                SELECT 1
                FROM project_members pm
                WHERE pm.project_id = p.project_id
                  AND pm.user_id = %s
            )
          )
        LIMIT 1
        """,
        (project_id, user_id, user_id),
    )
    return cursor.fetchone() is not None


def ensure_project_access(cursor, project_id: str, current_user: dict) -> None:
    if not user_can_access_project(cursor, project_id, current_user):
        raise HTTPException(status_code=404, detail="Project not found")


def append_project_access_filter(filters: list[str], params: list[object], current_user: dict, project_alias: str) -> None:
    if is_admin(current_user):
        return
    filters.append(
        f"""
        (
            {project_alias}.pm_user_id = %s
            OR EXISTS (
                SELECT 1
                FROM project_members pm_acl
                WHERE pm_acl.project_id = {project_alias}.project_id
                  AND pm_acl.user_id = %s
            )
        )
        """
    )
    params.extend([current_user["user_id"], current_user["user_id"]])
