--
-- PostgreSQL database dump
--

\restrict HImefRpYALa6MUY4ekFE70R5YZZ8q71tcJHzmdqFNYQyQ6ktnbMedJffGwpzaoo

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg12+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.tasks DROP CONSTRAINT IF EXISTS tasks_source_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.tasks DROP CONSTRAINT IF EXISTS tasks_source_analysis_id_fkey;
ALTER TABLE IF EXISTS ONLY public.tasks DROP CONSTRAINT IF EXISTS tasks_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.schedules DROP CONSTRAINT IF EXISTS schedules_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.risks DROP CONSTRAINT IF EXISTS risks_source_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.risks DROP CONSTRAINT IF EXISTS risks_source_analysis_id_fkey;
ALTER TABLE IF EXISTS ONLY public.risks DROP CONSTRAINT IF EXISTS risks_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_usage_entries DROP CONSTRAINT IF EXISTS resource_usage_entries_resource_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_usage_entries DROP CONSTRAINT IF EXISTS resource_usage_entries_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_usage_entries DROP CONSTRAINT IF EXISTS resource_usage_entries_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_usage_entries DROP CONSTRAINT IF EXISTS resource_usage_entries_allocation_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_profiles DROP CONSTRAINT IF EXISTS resource_profiles_owner_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_profiles DROP CONSTRAINT IF EXISTS resource_profiles_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_demands DROP CONSTRAINT IF EXISTS resource_demands_source_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_demands DROP CONSTRAINT IF EXISTS resource_demands_source_analysis_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_demands DROP CONSTRAINT IF EXISTS resource_demands_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_calendar_blocks DROP CONSTRAINT IF EXISTS resource_calendar_blocks_resource_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_calendar_blocks DROP CONSTRAINT IF EXISTS resource_calendar_blocks_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_calendar_blocks DROP CONSTRAINT IF EXISTS resource_calendar_blocks_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_resource_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_demand_id_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_assignee_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_members DROP CONSTRAINT IF EXISTS project_members_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_members DROP CONSTRAINT IF EXISTS project_members_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_knowledge_items DROP CONSTRAINT IF EXISTS project_knowledge_items_source_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_knowledge_items DROP CONSTRAINT IF EXISTS project_knowledge_items_source_analysis_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_knowledge_items DROP CONSTRAINT IF EXISTS project_knowledge_items_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_decisions DROP CONSTRAINT IF EXISTS project_decisions_source_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_decisions DROP CONSTRAINT IF EXISTS project_decisions_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_response_received_by_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_requested_by_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_cost_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_candidates DROP CONSTRAINT IF EXISTS project_cost_candidates_reviewed_by_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_candidates DROP CONSTRAINT IF EXISTS project_cost_candidates_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_candidates DROP CONSTRAINT IF EXISTS project_cost_candidates_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.password_reset_tokens DROP CONSTRAINT IF EXISTS password_reset_tokens_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.meetings DROP CONSTRAINT IF EXISTS meetings_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.meeting_attendees DROP CONSTRAINT IF EXISTS meeting_attendees_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.meeting_attendees DROP CONSTRAINT IF EXISTS meeting_attendees_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.meeting_analyses DROP CONSTRAINT IF EXISTS meeting_analyses_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.email_distributions DROP CONSTRAINT IF EXISTS email_distributions_requested_by_fkey;
ALTER TABLE IF EXISTS ONLY public.email_distributions DROP CONSTRAINT IF EXISTS email_distributions_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.email_distributions DROP CONSTRAINT IF EXISTS email_distributions_analysis_id_fkey;
ALTER TABLE IF EXISTS ONLY public.email_delivery_attempts DROP CONSTRAINT IF EXISTS email_delivery_attempts_distribution_id_fkey;
ALTER TABLE IF EXISTS ONLY public.collection_audio_assets DROP CONSTRAINT IF EXISTS collection_audio_assets_session_id_fkey;
ALTER TABLE IF EXISTS ONLY public.collection_analysis_jobs DROP CONSTRAINT IF EXISTS collection_analysis_jobs_session_id_fkey;
ALTER TABLE IF EXISTS ONLY public.collection_analysis_jobs DROP CONSTRAINT IF EXISTS collection_analysis_jobs_asset_id_fkey;
ALTER TABLE IF EXISTS ONLY public.analysis_jobs DROP CONSTRAINT IF EXISTS analysis_jobs_meeting_id_fkey;
ALTER TABLE IF EXISTS ONLY public.access_tokens DROP CONSTRAINT IF EXISTS access_tokens_user_id_fkey;
DROP INDEX IF EXISTS public.idx_resource_usage_entries_project_date;
DROP INDEX IF EXISTS public.idx_resource_usage_entries_allocation;
DROP INDEX IF EXISTS public.idx_resource_profiles_type_status;
DROP INDEX IF EXISTS public.idx_resource_profiles_name;
DROP INDEX IF EXISTS public.idx_resource_calendar_blocks_resource_window;
DROP INDEX IF EXISTS public.idx_resource_calendar_blocks_project;
DROP INDEX IF EXISTS public.idx_resource_allocations_resource_window;
DROP INDEX IF EXISTS public.idx_resource_allocations_resource_id_window;
DROP INDEX IF EXISTS public.idx_resource_allocations_project;
DROP INDEX IF EXISTS public.idx_resource_allocations_demand;
DROP INDEX IF EXISTS public.idx_project_members_user_allocation;
DROP INDEX IF EXISTS public.idx_project_knowledge_items_source_analysis;
DROP INDEX IF EXISTS public.idx_project_knowledge_items_project_kind;
DROP INDEX IF EXISTS public.idx_project_cost_handoffs_target_status;
DROP INDEX IF EXISTS public.idx_project_cost_handoffs_send_due;
DROP INDEX IF EXISTS public.idx_project_cost_handoffs_queued;
DROP INDEX IF EXISTS public.idx_project_cost_handoffs_project_status;
DROP INDEX IF EXISTS public.idx_project_cost_handoffs_completed_at;
DROP INDEX IF EXISTS public.idx_project_cost_candidates_source;
DROP INDEX IF EXISTS public.idx_project_cost_candidates_reviewed_by;
DROP INDEX IF EXISTS public.idx_project_cost_candidates_project_status;
DROP INDEX IF EXISTS public.idx_password_reset_tokens_user_status;
DROP INDEX IF EXISTS public.idx_password_reset_tokens_pending_hash;
DROP INDEX IF EXISTS public.idx_meeting_analyses_source_collection_job;
DROP INDEX IF EXISTS public.idx_email_distributions_retry_due;
DROP INDEX IF EXISTS public.idx_email_distributions_meeting;
DROP INDEX IF EXISTS public.idx_email_distributions_analysis_active;
DROP INDEX IF EXISTS public.idx_email_delivery_attempts_distribution;
DROP INDEX IF EXISTS public.idx_collection_jobs_meeting;
DROP INDEX IF EXISTS public.idx_collection_jobs_claimable;
DROP INDEX IF EXISTS public.idx_collection_jobs_callback_retry;
DROP INDEX IF EXISTS public.idx_access_tokens_user;
DROP INDEX IF EXISTS public.idx_access_tokens_active;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_employee_no_key;
ALTER TABLE IF EXISTS ONLY public.tasks DROP CONSTRAINT IF EXISTS tasks_pkey;
ALTER TABLE IF EXISTS ONLY public.schema_migrations DROP CONSTRAINT IF EXISTS schema_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.schedules DROP CONSTRAINT IF EXISTS schedules_pkey;
ALTER TABLE IF EXISTS ONLY public.risks DROP CONSTRAINT IF EXISTS risks_pkey;
ALTER TABLE IF EXISTS ONLY public.resource_usage_entries DROP CONSTRAINT IF EXISTS resource_usage_entries_pkey;
ALTER TABLE IF EXISTS ONLY public.resource_profiles DROP CONSTRAINT IF EXISTS resource_profiles_pkey;
ALTER TABLE IF EXISTS ONLY public.resource_demands DROP CONSTRAINT IF EXISTS resource_demands_pkey;
ALTER TABLE IF EXISTS ONLY public.resource_calendar_blocks DROP CONSTRAINT IF EXISTS resource_calendar_blocks_pkey;
ALTER TABLE IF EXISTS ONLY public.resource_allocations DROP CONSTRAINT IF EXISTS resource_allocations_pkey;
ALTER TABLE IF EXISTS ONLY public.projects DROP CONSTRAINT IF EXISTS projects_pkey;
ALTER TABLE IF EXISTS ONLY public.project_members DROP CONSTRAINT IF EXISTS project_members_pkey;
ALTER TABLE IF EXISTS ONLY public.project_knowledge_items DROP CONSTRAINT IF EXISTS project_knowledge_items_source_analysis_id_item_kind_source_key;
ALTER TABLE IF EXISTS ONLY public.project_knowledge_items DROP CONSTRAINT IF EXISTS project_knowledge_items_pkey;
ALTER TABLE IF EXISTS ONLY public.project_decisions DROP CONSTRAINT IF EXISTS project_decisions_pkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_pkey;
ALTER TABLE IF EXISTS ONLY public.project_cost_handoffs DROP CONSTRAINT IF EXISTS project_cost_handoffs_cost_id_target_system_key;
ALTER TABLE IF EXISTS ONLY public.project_cost_candidates DROP CONSTRAINT IF EXISTS project_cost_candidates_pkey;
ALTER TABLE IF EXISTS ONLY public.password_reset_tokens DROP CONSTRAINT IF EXISTS password_reset_tokens_token_hash_key;
ALTER TABLE IF EXISTS ONLY public.password_reset_tokens DROP CONSTRAINT IF EXISTS password_reset_tokens_pkey;
ALTER TABLE IF EXISTS ONLY public.meetings DROP CONSTRAINT IF EXISTS meetings_pkey;
ALTER TABLE IF EXISTS ONLY public.meeting_attendees DROP CONSTRAINT IF EXISTS meeting_attendees_pkey;
ALTER TABLE IF EXISTS ONLY public.meeting_analyses DROP CONSTRAINT IF EXISTS meeting_analyses_pkey;
ALTER TABLE IF EXISTS ONLY public.email_distributions DROP CONSTRAINT IF EXISTS email_distributions_pkey;
ALTER TABLE IF EXISTS ONLY public.email_delivery_attempts DROP CONSTRAINT IF EXISTS email_delivery_attempts_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_workers DROP CONSTRAINT IF EXISTS collection_workers_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_upload_sessions DROP CONSTRAINT IF EXISTS collection_upload_sessions_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_job_event_logs DROP CONSTRAINT IF EXISTS collection_job_event_logs_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_audio_assets DROP CONSTRAINT IF EXISTS collection_audio_assets_pkey;
ALTER TABLE IF EXISTS ONLY public.collection_analysis_jobs DROP CONSTRAINT IF EXISTS collection_analysis_jobs_pkey;
ALTER TABLE IF EXISTS ONLY public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_pkey;
ALTER TABLE IF EXISTS ONLY public.analysis_jobs DROP CONSTRAINT IF EXISTS analysis_jobs_pkey;
ALTER TABLE IF EXISTS ONLY public.access_tokens DROP CONSTRAINT IF EXISTS access_tokens_token_hash_key;
ALTER TABLE IF EXISTS ONLY public.access_tokens DROP CONSTRAINT IF EXISTS access_tokens_pkey;
ALTER TABLE IF EXISTS public.collection_job_event_logs ALTER COLUMN event_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.audit_logs ALTER COLUMN log_id DROP DEFAULT;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.tasks;
DROP TABLE IF EXISTS public.schema_migrations;
DROP TABLE IF EXISTS public.schedules;
DROP TABLE IF EXISTS public.risks;
DROP TABLE IF EXISTS public.resource_usage_entries;
DROP TABLE IF EXISTS public.resource_profiles;
DROP TABLE IF EXISTS public.resource_demands;
DROP TABLE IF EXISTS public.resource_calendar_blocks;
DROP TABLE IF EXISTS public.resource_allocations;
DROP TABLE IF EXISTS public.projects;
DROP TABLE IF EXISTS public.project_members;
DROP TABLE IF EXISTS public.project_knowledge_items;
DROP TABLE IF EXISTS public.project_decisions;
DROP TABLE IF EXISTS public.project_cost_handoffs;
DROP TABLE IF EXISTS public.project_cost_candidates;
DROP TABLE IF EXISTS public.password_reset_tokens;
DROP TABLE IF EXISTS public.meetings;
DROP TABLE IF EXISTS public.meeting_attendees;
DROP TABLE IF EXISTS public.meeting_analyses;
DROP TABLE IF EXISTS public.email_distributions;
DROP TABLE IF EXISTS public.email_delivery_attempts;
DROP TABLE IF EXISTS public.collection_workers;
DROP TABLE IF EXISTS public.collection_upload_sessions;
DROP SEQUENCE IF EXISTS public.collection_job_event_logs_event_id_seq;
DROP TABLE IF EXISTS public.collection_job_event_logs;
DROP TABLE IF EXISTS public.collection_audio_assets;
DROP TABLE IF EXISTS public.collection_analysis_jobs;
DROP SEQUENCE IF EXISTS public.audit_logs_log_id_seq;
DROP TABLE IF EXISTS public.audit_logs;
DROP TABLE IF EXISTS public.analysis_jobs;
DROP TABLE IF EXISTS public.access_tokens;
DROP EXTENSION IF EXISTS vector;
--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_tokens (
    token_id text NOT NULL,
    user_id text NOT NULL,
    token_hash text NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    last_used_at timestamp with time zone
);


--
-- Name: analysis_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analysis_jobs (
    job_id text NOT NULL,
    meeting_id text NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    analysis_server_url text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    error_message text
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    log_id bigint NOT NULL,
    actor_user_id text,
    action_type text NOT NULL,
    target_table text NOT NULL,
    target_id text NOT NULL,
    before_value jsonb,
    after_value jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_logs_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_logs_log_id_seq OWNED BY public.audit_logs.log_id;


--
-- Name: collection_analysis_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_analysis_jobs (
    job_id text NOT NULL,
    session_id text,
    asset_id text,
    project_id text NOT NULL,
    meeting_id text NOT NULL,
    transcript_text text,
    language text DEFAULT 'ko'::text NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 3 NOT NULL,
    claimed_by text,
    lease_expires_at timestamp with time zone,
    model_name text,
    result_json jsonb,
    last_error text,
    platform_callback_status text DEFAULT 'pending'::text NOT NULL,
    platform_callback_attempt_count integer DEFAULT 0 NOT NULL,
    platform_callback_max_attempts integer DEFAULT 5 NOT NULL,
    platform_callback_next_attempt_at timestamp with time zone,
    platform_callback_last_attempt_at timestamp with time zone,
    platform_callback_completed_at timestamp with time zone,
    platform_callback_last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: collection_audio_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_audio_assets (
    asset_id text NOT NULL,
    session_id text NOT NULL,
    project_id text NOT NULL,
    meeting_id text NOT NULL,
    storage_uri text,
    file_name text,
    content_type text,
    size_bytes bigint,
    checksum_sha256 text,
    duration_seconds numeric(12,3),
    status text DEFAULT 'stored'::text NOT NULL,
    validation_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: collection_job_event_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_job_event_logs (
    event_id bigint NOT NULL,
    job_id text NOT NULL,
    worker_id text,
    event_type text NOT NULL,
    before_status text,
    after_status text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: collection_job_event_logs_event_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.collection_job_event_logs_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collection_job_event_logs_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.collection_job_event_logs_event_id_seq OWNED BY public.collection_job_event_logs.event_id;


--
-- Name: collection_upload_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_upload_sessions (
    session_id text NOT NULL,
    project_id text NOT NULL,
    meeting_id text NOT NULL,
    requested_by text,
    file_name text,
    content_type text,
    expected_size_bytes bigint,
    checksum_sha256 text,
    upload_token_hash text NOT NULL,
    status text DEFAULT 'created'::text NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: collection_workers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_workers (
    worker_id text NOT NULL,
    worker_name text,
    status text DEFAULT 'active'::text NOT NULL,
    current_job_id text,
    last_heartbeat_at timestamp with time zone DEFAULT now() NOT NULL,
    model_name text,
    host_info jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: email_delivery_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_delivery_attempts (
    attempt_id text NOT NULL,
    distribution_id text NOT NULL,
    recipient_email text NOT NULL,
    recipient_name text,
    status text DEFAULT 'sent'::text NOT NULL,
    provider_message_id text,
    error_message text,
    attempted_at timestamp with time zone DEFAULT now() NOT NULL,
    attempt_no integer DEFAULT 1 NOT NULL
);


--
-- Name: email_distributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_distributions (
    distribution_id text NOT NULL,
    meeting_id text NOT NULL,
    analysis_id text NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    recipients jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'sent'::text NOT NULL,
    delivery_mode text DEFAULT 'dev_log'::text NOT NULL,
    requested_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    last_error text,
    next_retry_at timestamp with time zone
);


--
-- Name: meeting_analyses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_analyses (
    analysis_id text NOT NULL,
    meeting_id text NOT NULL,
    source_collection_job_id text,
    source_asset_id text,
    status text DEFAULT 'draft'::text NOT NULL,
    model_name text NOT NULL,
    summary text NOT NULL,
    result_json jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    approved_at timestamp with time zone
);


--
-- Name: meeting_attendees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_attendees (
    meeting_id text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    meeting_id text NOT NULL,
    project_id text NOT NULL,
    title text NOT NULL,
    status text DEFAULT 'created'::text NOT NULL,
    audio_path text,
    transcript text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_tokens (
    reset_token_id text NOT NULL,
    user_id text NOT NULL,
    token_hash text NOT NULL,
    requested_email text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    last_verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_cost_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_cost_candidates (
    cost_id text NOT NULL,
    project_id text NOT NULL,
    source_type text DEFAULT 'resource_usage'::text NOT NULL,
    source_id text NOT NULL,
    cost_type text DEFAULT 'resource_usage'::text NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency text DEFAULT 'KRW'::text NOT NULL,
    status text DEFAULT 'candidate'::text NOT NULL,
    description text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    review_note text
);


--
-- Name: project_cost_handoffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_cost_handoffs (
    handoff_id text NOT NULL,
    cost_id text NOT NULL,
    project_id text NOT NULL,
    target_system text DEFAULT 'external_erp'::text NOT NULL,
    payload jsonb NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    external_reference text,
    requested_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    response_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    response_note text,
    response_received_by text,
    delivery_mode text DEFAULT 'dev_log'::text NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    last_error text,
    next_retry_at timestamp with time zone,
    last_attempted_at timestamp with time zone
);


--
-- Name: project_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_decisions (
    decision_id text NOT NULL,
    project_id text NOT NULL,
    source_meeting_id text,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_knowledge_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_knowledge_items (
    knowledge_id text NOT NULL,
    project_id text NOT NULL,
    source_meeting_id text,
    source_analysis_id text,
    item_kind text NOT NULL,
    source_item_index integer DEFAULT 0 NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    evidence_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    tags jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_members (
    project_id text NOT NULL,
    user_id text NOT NULL,
    project_role text DEFAULT 'member'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    allocation_percent numeric(5,2) DEFAULT 100.00 NOT NULL,
    planned_mm numeric(6,2) DEFAULT 1.00 NOT NULL,
    staffing_note text,
    annual_salary_krw numeric(14,0),
    allocated_cost_krw numeric(14,2)
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    project_id text NOT NULL,
    name text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    pm_user_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description text
);


--
-- Name: resource_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_allocations (
    allocation_id text NOT NULL,
    demand_id text NOT NULL,
    project_id text NOT NULL,
    resource_name text NOT NULL,
    resource_type text DEFAULT 'other'::text NOT NULL,
    allocation_type text DEFAULT 'assignment'::text NOT NULL,
    assignee_user_id text,
    quantity numeric(12,3),
    starts_on date,
    ends_on date,
    status text DEFAULT 'proposed'::text NOT NULL,
    conflict_reason text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resource_id text
);


--
-- Name: resource_calendar_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_calendar_blocks (
    block_id text NOT NULL,
    resource_id text NOT NULL,
    project_id text,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    block_type text DEFAULT 'blackout'::text NOT NULL,
    reason text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resource_calendar_blocks_check CHECK ((starts_on <= ends_on))
);


--
-- Name: resource_demands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_demands (
    demand_id text NOT NULL,
    project_id text NOT NULL,
    source_meeting_id text,
    source_analysis_id text,
    source_required_resource_index integer,
    name text NOT NULL,
    resource_type text DEFAULT 'other'::text NOT NULL,
    quantity numeric(12,3),
    needed_from date,
    needed_to date,
    reason text,
    evidence text,
    evidence_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    ai_confidence numeric(4,3),
    demand_status text DEFAULT 'candidate'::text NOT NULL,
    conversion_policy text DEFAULT 'manual_review_required'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: resource_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_profiles (
    resource_id text NOT NULL,
    resource_type text DEFAULT 'other'::text NOT NULL,
    resource_name text NOT NULL,
    capacity numeric(12,3) DEFAULT 1 NOT NULL,
    unit text DEFAULT 'unit'::text NOT NULL,
    location text,
    owner_user_id text,
    status text DEFAULT 'active'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: resource_usage_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_usage_entries (
    usage_id text NOT NULL,
    allocation_id text NOT NULL,
    project_id text NOT NULL,
    resource_id text,
    resource_name text NOT NULL,
    resource_type text DEFAULT 'other'::text NOT NULL,
    usage_date date NOT NULL,
    quantity numeric(12,3) NOT NULL,
    unit text DEFAULT 'unit'::text NOT NULL,
    cost_amount numeric(14,2),
    usage_status text DEFAULT 'recorded'::text NOT NULL,
    note text,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risks (
    risk_id text NOT NULL,
    project_id text NOT NULL,
    source_meeting_id text,
    source_analysis_id text,
    title text NOT NULL,
    level text DEFAULT 'medium'::text NOT NULL,
    evidence text,
    evidence_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    ai_confidence numeric(4,3),
    status text DEFAULT 'candidate'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedules (
    schedule_id text NOT NULL,
    project_id text NOT NULL,
    title text NOT NULL,
    start_date date,
    end_date date,
    milestone boolean DEFAULT false NOT NULL,
    status text DEFAULT 'planned'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    service text NOT NULL,
    version text NOT NULL,
    name text NOT NULL,
    checksum_sha256 text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    task_id text NOT NULL,
    project_id text NOT NULL,
    source_meeting_id text,
    source_analysis_id text,
    source_action_item_index integer,
    title text NOT NULL,
    description text,
    assignee text,
    due_date date,
    priority text DEFAULT 'medium'::text NOT NULL,
    ai_confidence numeric(4,3),
    evidence_refs jsonb DEFAULT '[]'::jsonb NOT NULL,
    conversion_policy text DEFAULT 'manual_review_required'::text NOT NULL,
    conversion_status text DEFAULT 'draft'::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    user_id text NOT NULL,
    employee_no text NOT NULL,
    name text NOT NULL,
    email text,
    role text DEFAULT 'member'::text NOT NULL,
    password_hash text NOT NULL,
    status text DEFAULT 'password_change_required'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- Name: collection_job_event_logs event_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_job_event_logs ALTER COLUMN event_id SET DEFAULT nextval('public.collection_job_event_logs_event_id_seq'::regclass);


--
-- Name: access_tokens access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_pkey PRIMARY KEY (token_id);


--
-- Name: access_tokens access_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: analysis_jobs analysis_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_pkey PRIMARY KEY (job_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- Name: collection_analysis_jobs collection_analysis_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_analysis_jobs
    ADD CONSTRAINT collection_analysis_jobs_pkey PRIMARY KEY (job_id);


--
-- Name: collection_audio_assets collection_audio_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_audio_assets
    ADD CONSTRAINT collection_audio_assets_pkey PRIMARY KEY (asset_id);


--
-- Name: collection_job_event_logs collection_job_event_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_job_event_logs
    ADD CONSTRAINT collection_job_event_logs_pkey PRIMARY KEY (event_id);


--
-- Name: collection_upload_sessions collection_upload_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_upload_sessions
    ADD CONSTRAINT collection_upload_sessions_pkey PRIMARY KEY (session_id);


--
-- Name: collection_workers collection_workers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_workers
    ADD CONSTRAINT collection_workers_pkey PRIMARY KEY (worker_id);


--
-- Name: email_delivery_attempts email_delivery_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_delivery_attempts
    ADD CONSTRAINT email_delivery_attempts_pkey PRIMARY KEY (attempt_id);


--
-- Name: email_distributions email_distributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_distributions
    ADD CONSTRAINT email_distributions_pkey PRIMARY KEY (distribution_id);


--
-- Name: meeting_analyses meeting_analyses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_analyses
    ADD CONSTRAINT meeting_analyses_pkey PRIMARY KEY (analysis_id);


--
-- Name: meeting_attendees meeting_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_pkey PRIMARY KEY (meeting_id, user_id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (meeting_id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (reset_token_id);


--
-- Name: password_reset_tokens password_reset_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: project_cost_candidates project_cost_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_candidates
    ADD CONSTRAINT project_cost_candidates_pkey PRIMARY KEY (cost_id);


--
-- Name: project_cost_handoffs project_cost_handoffs_cost_id_target_system_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_cost_id_target_system_key UNIQUE (cost_id, target_system);


--
-- Name: project_cost_handoffs project_cost_handoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_pkey PRIMARY KEY (handoff_id);


--
-- Name: project_decisions project_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_decisions
    ADD CONSTRAINT project_decisions_pkey PRIMARY KEY (decision_id);


--
-- Name: project_knowledge_items project_knowledge_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_knowledge_items
    ADD CONSTRAINT project_knowledge_items_pkey PRIMARY KEY (knowledge_id);


--
-- Name: project_knowledge_items project_knowledge_items_source_analysis_id_item_kind_source_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_knowledge_items
    ADD CONSTRAINT project_knowledge_items_source_analysis_id_item_kind_source_key UNIQUE (source_analysis_id, item_kind, source_item_index);


--
-- Name: project_members project_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_pkey PRIMARY KEY (project_id, user_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (project_id);


--
-- Name: resource_allocations resource_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_pkey PRIMARY KEY (allocation_id);


--
-- Name: resource_calendar_blocks resource_calendar_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_calendar_blocks
    ADD CONSTRAINT resource_calendar_blocks_pkey PRIMARY KEY (block_id);


--
-- Name: resource_demands resource_demands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_demands
    ADD CONSTRAINT resource_demands_pkey PRIMARY KEY (demand_id);


--
-- Name: resource_profiles resource_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_profiles
    ADD CONSTRAINT resource_profiles_pkey PRIMARY KEY (resource_id);


--
-- Name: resource_usage_entries resource_usage_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_usage_entries
    ADD CONSTRAINT resource_usage_entries_pkey PRIMARY KEY (usage_id);


--
-- Name: risks risks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risks
    ADD CONSTRAINT risks_pkey PRIMARY KEY (risk_id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (schedule_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (service, version);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (task_id);


--
-- Name: users users_employee_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_employee_no_key UNIQUE (employee_no);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_access_tokens_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_tokens_active ON public.access_tokens USING btree (token_hash) WHERE (revoked_at IS NULL);


--
-- Name: idx_access_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_tokens_user ON public.access_tokens USING btree (user_id);


--
-- Name: idx_collection_jobs_callback_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collection_jobs_callback_retry ON public.collection_analysis_jobs USING btree (platform_callback_status, platform_callback_next_attempt_at) WHERE (platform_callback_status = ANY (ARRAY['pending'::text, 'retry_wait'::text]));


--
-- Name: idx_collection_jobs_claimable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collection_jobs_claimable ON public.collection_analysis_jobs USING btree (status, priority, created_at);


--
-- Name: idx_collection_jobs_meeting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collection_jobs_meeting ON public.collection_analysis_jobs USING btree (meeting_id);


--
-- Name: idx_email_delivery_attempts_distribution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_delivery_attempts_distribution ON public.email_delivery_attempts USING btree (distribution_id, attempted_at DESC);


--
-- Name: idx_email_distributions_analysis_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_email_distributions_analysis_active ON public.email_distributions USING btree (analysis_id) WHERE (status = ANY (ARRAY['queued'::text, 'sending'::text, 'sent'::text]));


--
-- Name: idx_email_distributions_meeting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_distributions_meeting ON public.email_distributions USING btree (meeting_id, created_at DESC);


--
-- Name: idx_email_distributions_retry_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_distributions_retry_due ON public.email_distributions USING btree (next_retry_at, created_at) WHERE (status = ANY (ARRAY['retry_wait'::text, 'partial_failed'::text, 'failed'::text]));


--
-- Name: idx_meeting_analyses_source_collection_job; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_meeting_analyses_source_collection_job ON public.meeting_analyses USING btree (source_collection_job_id) WHERE (source_collection_job_id IS NOT NULL);


--
-- Name: idx_password_reset_tokens_pending_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_reset_tokens_pending_hash ON public.password_reset_tokens USING btree (token_hash) WHERE (status = 'pending'::text);


--
-- Name: idx_password_reset_tokens_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_reset_tokens_user_status ON public.password_reset_tokens USING btree (user_id, status, expires_at);


--
-- Name: idx_project_cost_candidates_project_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_candidates_project_status ON public.project_cost_candidates USING btree (project_id, status, created_at DESC);


--
-- Name: idx_project_cost_candidates_reviewed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_candidates_reviewed_by ON public.project_cost_candidates USING btree (reviewed_by, reviewed_at DESC);


--
-- Name: idx_project_cost_candidates_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_project_cost_candidates_source ON public.project_cost_candidates USING btree (source_type, source_id);


--
-- Name: idx_project_cost_handoffs_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_handoffs_completed_at ON public.project_cost_handoffs USING btree (completed_at DESC) WHERE (completed_at IS NOT NULL);


--
-- Name: idx_project_cost_handoffs_project_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_handoffs_project_status ON public.project_cost_handoffs USING btree (project_id, status, created_at DESC);


--
-- Name: idx_project_cost_handoffs_queued; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_handoffs_queued ON public.project_cost_handoffs USING btree (created_at) WHERE (status = 'queued'::text);


--
-- Name: idx_project_cost_handoffs_send_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_handoffs_send_due ON public.project_cost_handoffs USING btree (next_retry_at, created_at) WHERE (status = 'retry_wait'::text);


--
-- Name: idx_project_cost_handoffs_target_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_cost_handoffs_target_status ON public.project_cost_handoffs USING btree (target_system, status, created_at DESC);


--
-- Name: idx_project_knowledge_items_project_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_knowledge_items_project_kind ON public.project_knowledge_items USING btree (project_id, item_kind, created_at DESC);


--
-- Name: idx_project_knowledge_items_source_analysis; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_knowledge_items_source_analysis ON public.project_knowledge_items USING btree (source_analysis_id);


--
-- Name: idx_project_members_user_allocation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_members_user_allocation ON public.project_members USING btree (user_id, project_id);


--
-- Name: idx_resource_allocations_demand; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_allocations_demand ON public.resource_allocations USING btree (demand_id);


--
-- Name: idx_resource_allocations_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_allocations_project ON public.resource_allocations USING btree (project_id, starts_on, ends_on);


--
-- Name: idx_resource_allocations_resource_id_window; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_allocations_resource_id_window ON public.resource_allocations USING btree (resource_id, starts_on, ends_on) WHERE ((status = ANY (ARRAY['proposed'::text, 'confirmed'::text])) AND (resource_id IS NOT NULL));


--
-- Name: idx_resource_allocations_resource_window; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_allocations_resource_window ON public.resource_allocations USING btree (resource_name, starts_on, ends_on) WHERE (status = ANY (ARRAY['proposed'::text, 'confirmed'::text]));


--
-- Name: idx_resource_calendar_blocks_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_calendar_blocks_project ON public.resource_calendar_blocks USING btree (project_id, starts_on DESC);


--
-- Name: idx_resource_calendar_blocks_resource_window; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_calendar_blocks_resource_window ON public.resource_calendar_blocks USING btree (resource_id, starts_on, ends_on);


--
-- Name: idx_resource_profiles_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_profiles_name ON public.resource_profiles USING btree (resource_name);


--
-- Name: idx_resource_profiles_type_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_profiles_type_status ON public.resource_profiles USING btree (resource_type, status);


--
-- Name: idx_resource_usage_entries_allocation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_usage_entries_allocation ON public.resource_usage_entries USING btree (allocation_id, usage_date DESC);


--
-- Name: idx_resource_usage_entries_project_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_usage_entries_project_date ON public.resource_usage_entries USING btree (project_id, usage_date DESC);


--
-- Name: access_tokens access_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: analysis_jobs analysis_jobs_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analysis_jobs
    ADD CONSTRAINT analysis_jobs_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: collection_analysis_jobs collection_analysis_jobs_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_analysis_jobs
    ADD CONSTRAINT collection_analysis_jobs_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.collection_audio_assets(asset_id);


--
-- Name: collection_analysis_jobs collection_analysis_jobs_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_analysis_jobs
    ADD CONSTRAINT collection_analysis_jobs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.collection_upload_sessions(session_id);


--
-- Name: collection_audio_assets collection_audio_assets_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_audio_assets
    ADD CONSTRAINT collection_audio_assets_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.collection_upload_sessions(session_id);


--
-- Name: email_delivery_attempts email_delivery_attempts_distribution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_delivery_attempts
    ADD CONSTRAINT email_delivery_attempts_distribution_id_fkey FOREIGN KEY (distribution_id) REFERENCES public.email_distributions(distribution_id) ON DELETE CASCADE;


--
-- Name: email_distributions email_distributions_analysis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_distributions
    ADD CONSTRAINT email_distributions_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES public.meeting_analyses(analysis_id);


--
-- Name: email_distributions email_distributions_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_distributions
    ADD CONSTRAINT email_distributions_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: email_distributions email_distributions_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_distributions
    ADD CONSTRAINT email_distributions_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(user_id);


--
-- Name: meeting_analyses meeting_analyses_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_analyses
    ADD CONSTRAINT meeting_analyses_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: meeting_attendees meeting_attendees_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(meeting_id) ON DELETE CASCADE;


--
-- Name: meeting_attendees meeting_attendees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: meetings meetings_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: project_cost_candidates project_cost_candidates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_candidates
    ADD CONSTRAINT project_cost_candidates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: project_cost_candidates project_cost_candidates_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_candidates
    ADD CONSTRAINT project_cost_candidates_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: project_cost_candidates project_cost_candidates_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_candidates
    ADD CONSTRAINT project_cost_candidates_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(user_id);


--
-- Name: project_cost_handoffs project_cost_handoffs_cost_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_cost_id_fkey FOREIGN KEY (cost_id) REFERENCES public.project_cost_candidates(cost_id) ON DELETE CASCADE;


--
-- Name: project_cost_handoffs project_cost_handoffs_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: project_cost_handoffs project_cost_handoffs_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(user_id);


--
-- Name: project_cost_handoffs project_cost_handoffs_response_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_cost_handoffs
    ADD CONSTRAINT project_cost_handoffs_response_received_by_fkey FOREIGN KEY (response_received_by) REFERENCES public.users(user_id);


--
-- Name: project_decisions project_decisions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_decisions
    ADD CONSTRAINT project_decisions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: project_decisions project_decisions_source_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_decisions
    ADD CONSTRAINT project_decisions_source_meeting_id_fkey FOREIGN KEY (source_meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: project_knowledge_items project_knowledge_items_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_knowledge_items
    ADD CONSTRAINT project_knowledge_items_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: project_knowledge_items project_knowledge_items_source_analysis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_knowledge_items
    ADD CONSTRAINT project_knowledge_items_source_analysis_id_fkey FOREIGN KEY (source_analysis_id) REFERENCES public.meeting_analyses(analysis_id);


--
-- Name: project_knowledge_items project_knowledge_items_source_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_knowledge_items
    ADD CONSTRAINT project_knowledge_items_source_meeting_id_fkey FOREIGN KEY (source_meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: project_members project_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: resource_allocations resource_allocations_assignee_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_assignee_user_id_fkey FOREIGN KEY (assignee_user_id) REFERENCES public.users(user_id);


--
-- Name: resource_allocations resource_allocations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: resource_allocations resource_allocations_demand_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_demand_id_fkey FOREIGN KEY (demand_id) REFERENCES public.resource_demands(demand_id) ON DELETE CASCADE;


--
-- Name: resource_allocations resource_allocations_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: resource_allocations resource_allocations_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_allocations
    ADD CONSTRAINT resource_allocations_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES public.resource_profiles(resource_id);


--
-- Name: resource_calendar_blocks resource_calendar_blocks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_calendar_blocks
    ADD CONSTRAINT resource_calendar_blocks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: resource_calendar_blocks resource_calendar_blocks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_calendar_blocks
    ADD CONSTRAINT resource_calendar_blocks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: resource_calendar_blocks resource_calendar_blocks_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_calendar_blocks
    ADD CONSTRAINT resource_calendar_blocks_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES public.resource_profiles(resource_id) ON DELETE CASCADE;


--
-- Name: resource_demands resource_demands_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_demands
    ADD CONSTRAINT resource_demands_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: resource_demands resource_demands_source_analysis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_demands
    ADD CONSTRAINT resource_demands_source_analysis_id_fkey FOREIGN KEY (source_analysis_id) REFERENCES public.meeting_analyses(analysis_id);


--
-- Name: resource_demands resource_demands_source_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_demands
    ADD CONSTRAINT resource_demands_source_meeting_id_fkey FOREIGN KEY (source_meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: resource_profiles resource_profiles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_profiles
    ADD CONSTRAINT resource_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: resource_profiles resource_profiles_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_profiles
    ADD CONSTRAINT resource_profiles_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(user_id);


--
-- Name: resource_usage_entries resource_usage_entries_allocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_usage_entries
    ADD CONSTRAINT resource_usage_entries_allocation_id_fkey FOREIGN KEY (allocation_id) REFERENCES public.resource_allocations(allocation_id) ON DELETE CASCADE;


--
-- Name: resource_usage_entries resource_usage_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_usage_entries
    ADD CONSTRAINT resource_usage_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: resource_usage_entries resource_usage_entries_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_usage_entries
    ADD CONSTRAINT resource_usage_entries_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: resource_usage_entries resource_usage_entries_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_usage_entries
    ADD CONSTRAINT resource_usage_entries_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES public.resource_profiles(resource_id);


--
-- Name: risks risks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risks
    ADD CONSTRAINT risks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: risks risks_source_analysis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risks
    ADD CONSTRAINT risks_source_analysis_id_fkey FOREIGN KEY (source_analysis_id) REFERENCES public.meeting_analyses(analysis_id);


--
-- Name: risks risks_source_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risks
    ADD CONSTRAINT risks_source_meeting_id_fkey FOREIGN KEY (source_meeting_id) REFERENCES public.meetings(meeting_id);


--
-- Name: schedules schedules_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: tasks tasks_source_analysis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_source_analysis_id_fkey FOREIGN KEY (source_analysis_id) REFERENCES public.meeting_analyses(analysis_id);


--
-- Name: tasks tasks_source_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_source_meeting_id_fkey FOREIGN KEY (source_meeting_id) REFERENCES public.meetings(meeting_id);


--
-- PostgreSQL database dump complete
--

\unrestrict HImefRpYALa6MUY4ekFE70R5YZZ8q71tcJHzmdqFNYQyQ6ktnbMedJffGwpzaoo

