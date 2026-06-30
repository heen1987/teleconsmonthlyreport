--
-- PostgreSQL database dump
--

\restrict LcMaWRK1juSRmFcraUZ1LG8wbCQN2uIR2UIQalD3dTHWIwjAqJhkW8a2jk3IawO

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
-- Data for Name: analysis_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.analysis_jobs (job_id, meeting_id, status, analysis_server_url, requested_at, completed_at, error_message) FROM stdin;
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_logs (log_id, actor_user_id, action_type, target_table, target_id, before_value, after_value, created_at) FROM stdin;
1	\N	seed_demo_company	company_fixture	SSK-TECH	\N	{"source": {"file_name": "saessak_virtual_company_dataset_named50_revised.xlsx", "extracted_at": "2026-06-30T10:53:41", "source_path_note": "User-provided Google Drive workbook path; Korean path omitted for cross-platform parsing."}, "company": {"ceo": "김도윤", "note": "교육·실습·테스트 목적의 100% 가상 데이터", "industry": "AI·클라우드 기반 B2B 솔루션 개발", "headcount": 50, "company_id": "SSK-TECH", "founded_on": "2021-03-15", "fiscal_year": "2026", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "headquarters": "서울특별시 마포구 디지털로 128", "project_count": 15, "headcount_summary": "경영본부 10명 / 연구소 15명 / 개발본부 25명", "annual_revenue_krw": 10000000000, "annual_revenue_label": "100억 원", "organization_summary": "3개 본부: 경영본부, 연구소, 개발본부"}, "summary": {"duties": {"SRE": 1, "AI리드": 1, "HR담당": 1, "R&D팀장": 1, "UI개발자": 1, "모바일QA": 1, "API개발자": 1, "NLP연구원": 1, "iOS개발자": 1, "기획지원": 1, "기획팀장": 1, "대표이사": 1, "연구소장": 1, "연구지원": 1, "웹개발자": 1, "인사팀장": 1, "재무지원": 1, "재무팀장": 1, "퍼블리셔": 1, "MLOps연구원": 1, "ML엔지니어": 1, "QA엔지니어": 1, "UX엔지니어": 1, "QA/DevOps팀장": 1, "개발본부장": 1, "모바일팀장": 1, "백엔드팀장": 1, "Android개발자": 1, "Flutter개발자": 1, "DevOps엔지니어": 1, "경영지원실장": 1, "데이터분석가": 1, "백엔드개발자": 2, "사업기획담당": 1, "주니어개발자": 1, "주니어연구원": 1, "플랫폼연구원": 1, "회계/자금담당": 1, "데이터연구팀장": 1, "시스템아키텍트": 1, "프론트엔드팀장": 1, "보안/인프라리드": 1, "데이터베이스리드": 1, "데이터어시스턴트": 1, "컴퓨터비전연구원": 1, "클라우드운영담당": 1, "테스트자동화담당": 1, "프론트엔드개발자": 1, "데이터사이언티스트": 1}, "headcount": 50, "positions": {"사원": 13, "선임": 18, "수석": 4, "책임": 14, "대표이사": 1}, "team_count": 11, "project_count": 15, "project_sizes": {"P-2026-001": 8, "P-2026-002": 5, "P-2026-003": 6, "P-2026-004": 8, "P-2026-005": 10, "P-2026-006": 11, "P-2026-007": 7, "P-2026-008": 12, "P-2026-009": 7, "P-2026-010": 9, "P-2026-011": 4, "P-2026-012": 11, "P-2026-013": 13, "P-2026-014": 11, "P-2026-015": 14}, "division_count": 3, "assignment_count": 136, "project_planned_mm": {"P-2026-001": 2.35, "P-2026-002": 1.45, "P-2026-003": 2.2, "P-2026-004": 2.05, "P-2026-005": 3.25, "P-2026-006": 2.95, "P-2026-007": 3.1, "P-2026-008": 3.15, "P-2026-009": 1.65, "P-2026-010": 3.1, "P-2026-011": 1.7, "P-2026-012": 3.25, "P-2026-013": 3.15, "P-2026-014": 2.55, "P-2026-015": 3.3}, "research_headcount": 15, "missing_project_pms": [], "management_headcount": 10, "development_headcount": 25, "headcount_by_division": {"연구소": 15, "개발본부": 25, "경영본부": 10}, "project_allocation_sum": {"P-2026-001": 2.35, "P-2026-002": 1.45, "P-2026-003": 2.2, "P-2026-004": 2.05, "P-2026-005": 3.25, "P-2026-006": 2.95, "P-2026-007": 3.1, "P-2026-008": 3.15, "P-2026-009": 1.65, "P-2026-010": 3.1, "P-2026-011": 1.7, "P-2026-012": 3.25, "P-2026-013": 3.15, "P-2026-014": 2.55, "P-2026-015": 3.3}, "total_annual_salary_krw": 3497380000, "duplicate_assignment_keys": [], "project_assignment_counts": {"P-2026-001": 8, "P-2026-002": 5, "P-2026-003": 6, "P-2026-004": 8, "P-2026-005": 10, "P-2026-006": 11, "P-2026-007": 7, "P-2026-008": 12, "P-2026-009": 7, "P-2026-010": 9, "P-2026-011": 4, "P-2026-012": 11, "P-2026-013": 13, "P-2026-014": 11, "P-2026-015": 14}, "project_count_by_division": {"연구소": 5, "개발본부": 8, "경영본부": 2}, "project_allocation_percent": {"P-2026-001": 235.0, "P-2026-002": 145.0, "P-2026-003": 220.0, "P-2026-004": 205.0, "P-2026-005": 325.0, "P-2026-006": 295.0, "P-2026-007": 310.0, "P-2026-008": 315.0, "P-2026-009": 165.0, "P-2026-010": 310.0, "P-2026-011": 170.0, "P-2026-012": 325.0, "P-2026-013": 315.0, "P-2026-014": 255.0, "P-2026-015": 330.0}}, "seed_policy": "upsert_users_resources_projects_project_members"}	2026-06-30 02:25:02.720936+00
2	\N	seed_demo_company	company_fixture	SSK-TECH	\N	{"source": {"file_name": "saessak_virtual_company_dataset_realistic_mm_allocation.xlsx", "extracted_at": "2026-06-30T11:33:02", "source_path_note": "User-provided Google Drive workbook path; Korean path omitted for cross-platform parsing."}, "company": {"ceo": "김도윤", "note": "교육·실습·테스트 목적의 100% 가상 데이터", "industry": "AI·클라우드 기반 B2B 솔루션 개발", "headcount": 50, "company_id": "SSK-TECH", "founded_on": "2021-03-15", "fiscal_year": "2026", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "headquarters": "서울특별시 마포구 디지털로 128", "project_count": 15, "headcount_summary": "경영본부 10명 / 연구소 15명 / 개발본부 25명", "annual_revenue_krw": 10000000000, "annual_revenue_label": "100억 원", "organization_summary": "3개 본부: 경영본부, 연구소, 개발본부"}, "summary": {"duties": {"SRE": 1, "AI리드": 1, "HR담당": 1, "R&D팀장": 1, "UI개발자": 1, "모바일QA": 1, "API개발자": 1, "NLP연구원": 1, "iOS개발자": 1, "기획지원": 1, "기획팀장": 1, "대표이사": 1, "연구소장": 1, "연구지원": 1, "웹개발자": 1, "인사팀장": 1, "재무지원": 1, "재무팀장": 1, "퍼블리셔": 1, "MLOps연구원": 1, "ML엔지니어": 1, "QA엔지니어": 1, "UX엔지니어": 1, "QA/DevOps팀장": 1, "개발본부장": 1, "모바일팀장": 1, "백엔드팀장": 1, "Android개발자": 1, "Flutter개발자": 1, "DevOps엔지니어": 1, "경영지원실장": 1, "데이터분석가": 1, "백엔드개발자": 2, "사업기획담당": 1, "주니어개발자": 1, "주니어연구원": 1, "플랫폼연구원": 1, "회계/자금담당": 1, "데이터연구팀장": 1, "시스템아키텍트": 1, "프론트엔드팀장": 1, "보안/인프라리드": 1, "데이터베이스리드": 1, "데이터어시스턴트": 1, "컴퓨터비전연구원": 1, "클라우드운영담당": 1, "테스트자동화담당": 1, "프론트엔드개발자": 1, "데이터사이언티스트": 1}, "headcount": 50, "positions": {"사원": 13, "선임": 18, "수석": 4, "책임": 14, "대표이사": 1}, "team_count": 11, "project_count": 15, "project_sizes": {"P-2026-001": 15, "P-2026-002": 5, "P-2026-003": 9, "P-2026-004": 8, "P-2026-005": 14, "P-2026-006": 21, "P-2026-007": 8, "P-2026-008": 16, "P-2026-009": 10, "P-2026-010": 18, "P-2026-011": 11, "P-2026-012": 14, "P-2026-013": 19, "P-2026-014": 20, "P-2026-015": 19}, "division_count": 3, "assignment_count": 207, "total_planned_mm": 50.0, "project_planned_mm": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "research_headcount": 15, "missing_project_pms": [], "management_headcount": 10, "total_labor_cost_krw": 432000000, "development_headcount": 25, "headcount_by_division": {"연구소": 15, "개발본부": 25, "경영본부": 10}, "max_single_planned_mm": 0.6, "project_allocation_sum": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "project_planned_mm_sum": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "employee_planned_mm_max": 1.0, "employee_planned_mm_min": 1.0, "total_annual_salary_krw": 3497380000, "duplicate_assignment_keys": [], "project_assignment_counts": {"P-2026-001": 15, "P-2026-002": 5, "P-2026-003": 9, "P-2026-004": 8, "P-2026-005": 14, "P-2026-006": 21, "P-2026-007": 8, "P-2026-008": 16, "P-2026-009": 10, "P-2026-010": 18, "P-2026-011": 11, "P-2026-012": 14, "P-2026-013": 19, "P-2026-014": 20, "P-2026-015": 19}, "project_count_by_division": {"연구소": 5, "개발본부": 8, "경영본부": 2}, "project_allocation_percent": {"P-2026-001": 340.0, "P-2026-002": 120.0, "P-2026-003": 230.0, "P-2026-004": 200.0, "P-2026-005": 360.0, "P-2026-006": 520.0, "P-2026-007": 300.0, "P-2026-008": 390.0, "P-2026-009": 250.0, "P-2026-010": 440.0, "P-2026-011": 250.0, "P-2026-012": 340.0, "P-2026-013": 400.0, "P-2026-014": 520.0, "P-2026-015": 340.0}, "project_labor_cost_sum_krw": {"P-2026-001": 33100000, "P-2026-002": 10600000, "P-2026-003": 19200000, "P-2026-004": 19100000, "P-2026-005": 31100000, "P-2026-006": 47200000, "P-2026-007": 23400000, "P-2026-008": 30800000, "P-2026-009": 21000000, "P-2026-010": 39200000, "P-2026-011": 17800000, "P-2026-012": 27600000, "P-2026-013": 36300000, "P-2026-014": 46000000, "P-2026-015": 29600000}, "employee_planned_mm_not_one_count": 0}, "seed_policy": "upsert_users_resources_projects_project_members"}	2026-06-30 02:35:11.207928+00
3	system	store_meeting_analysis_draft	meeting_analyses	ANL-e4b4e9c064a8	\N	{"status": "draft", "meeting_id": "MTG-CONN-CHECK-73432d53", "source_asset_id": null, "source_collection_job_id": "CJOB-f513765c040c"}	2026-06-30 02:42:19.090512+00
4	system	store_meeting_analysis_draft	meeting_analyses	ANL-53c902d4cb73	\N	{"status": "draft", "meeting_id": "MTG-PLATFORM-ANALYZE-469eba2d", "source_asset_id": null, "source_collection_job_id": "CJOB-15c587bbc50d"}	2026-06-30 02:46:57.106744+00
5	system	store_meeting_analysis_draft	meeting_analyses	ANL-717b9efa337c	\N	{"status": "draft", "meeting_id": "MTG-PLATFORM-ANALYZE-203de3b7", "source_asset_id": null, "source_collection_job_id": "CJOB-6c477635fa10"}	2026-06-30 02:51:14.353273+00
6	system	store_meeting_analysis_draft	meeting_analyses	ANL-4332d3a08f76	\N	{"status": "draft", "meeting_id": "MTG-PLATFORM-ANALYZE-ca7405c8", "source_asset_id": null, "source_collection_job_id": "CJOB-9cdf0ea0041e"}	2026-06-30 02:52:02.75345+00
7	system	store_meeting_analysis_draft	meeting_analyses	ANL-d166bf53fb58	\N	{"status": "draft", "meeting_id": "MTG-CODEX-130029", "source_asset_id": null, "source_collection_job_id": "CJOB-a8a9c32452f6"}	2026-06-30 04:00:51.067307+00
8	system	store_meeting_analysis_draft	meeting_analyses	ANL-e8e07779f584	\N	{"status": "draft", "meeting_id": "MTG-CODEX-131907", "source_asset_id": null, "source_collection_job_id": "CJOB-57dc6dd342fd"}	2026-06-30 04:21:12.300891+00
9	\N	seed_demo_company	company_fixture	SSK-TECH	\N	{"source": {"file_name": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "extracted_at": "2026-06-30T13:41:38", "login_policy": "직원은 사번을 로그인ID로 사용하고 초기비밀번호는 교육용 1234로 통일한다.", "source_path_note": "User-provided Google Drive workbook path; Korean path omitted for cross-platform parsing."}, "company": {"ceo": "김도윤", "note": "교육·실습·테스트 목적의 100% 가상 데이터", "industry": "AI·클라우드 기반 B2B 솔루션 개발", "headcount": 50, "company_id": "SSK-TECH", "founded_on": "2021-03-15", "fiscal_year": "2026", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "headquarters": "서울특별시 마포구 디지털로 128", "project_count": 15, "headcount_summary": "경영본부 10명 / 연구소 15명 / 개발본부 25명", "annual_revenue_krw": 10000000000, "annual_revenue_label": "100억 원", "organization_summary": "3개 본부: 경영본부, 연구소, 개발본부"}, "summary": {"duties": {"SRE": 1, "AI리드": 1, "HR담당": 1, "R&D팀장": 1, "UI개발자": 1, "모바일QA": 1, "API개발자": 1, "NLP연구원": 1, "iOS개발자": 1, "기획지원": 1, "기획팀장": 1, "대표이사": 1, "연구소장": 1, "연구지원": 1, "웹개발자": 1, "인사팀장": 1, "재무지원": 1, "재무팀장": 1, "퍼블리셔": 1, "MLOps연구원": 1, "ML엔지니어": 1, "QA엔지니어": 1, "UX엔지니어": 1, "QA/DevOps팀장": 1, "개발본부장": 1, "모바일팀장": 1, "백엔드팀장": 1, "Android개발자": 1, "Flutter개발자": 1, "DevOps엔지니어": 1, "경영지원실장": 1, "데이터분석가": 1, "백엔드개발자": 2, "사업기획담당": 1, "주니어개발자": 1, "주니어연구원": 1, "플랫폼연구원": 1, "회계/자금담당": 1, "데이터연구팀장": 1, "시스템아키텍트": 1, "프론트엔드팀장": 1, "보안/인프라리드": 1, "데이터베이스리드": 1, "데이터어시스턴트": 1, "컴퓨터비전연구원": 1, "클라우드운영담당": 1, "테스트자동화담당": 1, "프론트엔드개발자": 1, "데이터사이언티스트": 1}, "headcount": 50, "positions": {"사원": 13, "선임": 18, "수석": 4, "책임": 14, "대표이사": 1}, "team_count": 11, "account_count": 50, "project_count": 15, "project_sizes": {"P-2026-001": 15, "P-2026-002": 5, "P-2026-003": 9, "P-2026-004": 8, "P-2026-005": 14, "P-2026-006": 21, "P-2026-007": 8, "P-2026-008": 16, "P-2026-009": 10, "P-2026-010": 18, "P-2026-011": 11, "P-2026-012": 14, "P-2026-013": 19, "P-2026-014": 20, "P-2026-015": 19}, "division_count": 3, "assignment_count": 207, "total_planned_mm": 50.0, "auth_group_counts": {"LEAD": 6, "ADMIN": 1, "MEMBER": 31, "MANAGER": 12}, "project_planned_mm": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "research_headcount": 15, "account_role_counts": {"pl": 6, "pm": 10, "admin": 1, "member": 28, "finance": 3, "resource_manager": 2}, "login_method_counts": {"사번 로그인": 50}, "missing_project_pms": [], "login_id_match_count": 50, "management_headcount": 10, "total_labor_cost_krw": 432000000, "account_status_counts": {"활성": 50}, "development_headcount": 25, "headcount_by_division": {"연구소": 15, "개발본부": 25, "경영본부": 10}, "max_single_planned_mm": 0.6, "project_allocation_sum": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "project_planned_mm_sum": {"P-2026-001": 3.4, "P-2026-002": 1.2, "P-2026-003": 2.3, "P-2026-004": 2.0, "P-2026-005": 3.6, "P-2026-006": 5.2, "P-2026-007": 3.0, "P-2026-008": 3.9, "P-2026-009": 2.5, "P-2026-010": 4.4, "P-2026-011": 2.5, "P-2026-012": 3.4, "P-2026-013": 4.0, "P-2026-014": 5.2, "P-2026-015": 3.4}, "employee_planned_mm_max": 1.0, "employee_planned_mm_min": 1.0, "total_annual_salary_krw": 3497380000, "duplicate_assignment_keys": [], "project_assignment_counts": {"P-2026-001": 15, "P-2026-002": 5, "P-2026-003": 9, "P-2026-004": 8, "P-2026-005": 14, "P-2026-006": 21, "P-2026-007": 8, "P-2026-008": 16, "P-2026-009": 10, "P-2026-010": 18, "P-2026-011": 11, "P-2026-012": 14, "P-2026-013": 19, "P-2026-014": 20, "P-2026-015": 19}, "project_count_by_division": {"연구소": 5, "개발본부": 8, "경영본부": 2}, "project_allocation_percent": {"P-2026-001": 340.0, "P-2026-002": 120.0, "P-2026-003": 230.0, "P-2026-004": 200.0, "P-2026-005": 360.0, "P-2026-006": 520.0, "P-2026-007": 300.0, "P-2026-008": 390.0, "P-2026-009": 250.0, "P-2026-010": 440.0, "P-2026-011": 250.0, "P-2026-012": 340.0, "P-2026-013": 400.0, "P-2026-014": 520.0, "P-2026-015": 340.0}, "project_labor_cost_sum_krw": {"P-2026-001": 33100000, "P-2026-002": 10600000, "P-2026-003": 19200000, "P-2026-004": 19100000, "P-2026-005": 31100000, "P-2026-006": 47200000, "P-2026-007": 23400000, "P-2026-008": 30800000, "P-2026-009": 21000000, "P-2026-010": 39200000, "P-2026-011": 17800000, "P-2026-012": 27600000, "P-2026-013": 36300000, "P-2026-014": 46000000, "P-2026-015": 29600000}, "initial_password_1234_count": 50, "employee_planned_mm_not_one_count": 0}, "seed_policy": "upsert_users_resources_projects_project_members_with_employee_no_login"}	2026-06-30 04:43:50.467821+00
\.


--
-- Data for Name: collection_analysis_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_analysis_jobs (job_id, session_id, asset_id, project_id, meeting_id, transcript_text, language, status, priority, attempt_count, max_attempts, claimed_by, lease_expires_at, model_name, result_json, last_error, platform_callback_status, platform_callback_attempt_count, platform_callback_max_attempts, platform_callback_next_attempt_at, platform_callback_last_attempt_at, platform_callback_completed_at, platform_callback_last_error, created_at, updated_at, completed_at) FROM stdin;
\.


--
-- Data for Name: collection_audio_assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_audio_assets (asset_id, session_id, project_id, meeting_id, storage_uri, file_name, content_type, size_bytes, checksum_sha256, duration_seconds, status, validation_error, created_at) FROM stdin;
\.


--
-- Data for Name: collection_job_event_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_job_event_logs (event_id, job_id, worker_id, event_type, before_status, after_status, payload, created_at) FROM stdin;
30	CJOB-57dc6dd342fd	\N	platform_callback_failed	completed	completed	{"attempt": 1, "trigger": "completion", "next_status": "retry_wait", "callback_url": "http://localhost:8000/integrations/collection/jobs/CJOB-57dc6dd342fd/complete", "max_attempts": 5, "error_message": "Client error '404 Not Found' for url 'http://localhost:8000/integrations/collection/jobs/CJOB-57dc6dd342fd/complete'\\nFor more information check: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404", "next_attempt_at": "2026-06-30T04:21:43.593166+00:00"}	2026-06-30 04:21:13.616095+00
\.


--
-- Data for Name: collection_upload_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_upload_sessions (session_id, project_id, meeting_id, requested_by, file_name, content_type, expected_size_bytes, checksum_sha256, upload_token_hash, status, expires_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: collection_workers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_workers (worker_id, worker_name, status, current_job_id, last_heartbeat_at, model_name, host_info, created_at) FROM stdin;
connectivity-check	Connectivity Check	active	\N	2026-06-30 02:39:56.993564+00	qwen3:4b	{"runtime": "manual"}	2026-06-30 02:39:56.993564+00
mac-mini-worker-001	Mac mini Analysis Worker	active	\N	2026-06-30 04:46:09.217023+00	qwen3:4b	{"runtime": "ollama"}	2026-06-30 02:42:07.925687+00
\.


--
-- Data for Name: email_delivery_attempts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.email_delivery_attempts (attempt_id, distribution_id, recipient_email, recipient_name, status, provider_message_id, error_message, attempted_at, attempt_no) FROM stdin;
\.


--
-- Data for Name: email_distributions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.email_distributions (distribution_id, meeting_id, analysis_id, subject, body, recipients, status, delivery_mode, requested_by, created_at, sent_at, attempt_count, last_error, next_retry_at) FROM stdin;
\.


--
-- Data for Name: meeting_analyses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.meeting_analyses (analysis_id, meeting_id, source_collection_job_id, source_asset_id, status, model_name, summary, result_json, created_at, approved_at) FROM stdin;
\.


--
-- Data for Name: meeting_attendees; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.meeting_attendees (meeting_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: meetings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.meetings (meeting_id, project_id, title, status, audio_path, transcript, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: project_cost_candidates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_cost_candidates (cost_id, project_id, source_type, source_id, cost_type, amount, currency, status, description, created_by, created_at, reviewed_by, reviewed_at, review_note) FROM stdin;
\.


--
-- Data for Name: project_cost_handoffs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_cost_handoffs (handoff_id, cost_id, project_id, target_system, payload, status, external_reference, requested_by, created_at, completed_at, response_payload, response_note, response_received_by, delivery_mode, attempt_count, last_error, next_retry_at, last_attempted_at) FROM stdin;
\.


--
-- Data for Name: project_decisions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_decisions (decision_id, project_id, source_meeting_id, content, created_at) FROM stdin;
\.


--
-- Data for Name: project_knowledge_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_knowledge_items (knowledge_id, project_id, source_meeting_id, source_analysis_id, item_kind, source_item_index, title, content, evidence_refs, tags, status, created_at) FROM stdin;
\.


--
-- Data for Name: project_members; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_members (project_id, user_id, project_role, created_at, allocation_percent, planned_mm, staffing_note, annual_salary_krw, allocated_cost_krw) FROM stdin;
PJT-GUARD-101950	USR-a346f5d41279	pm	2026-06-30 01:19:51.701487+00	100.00	1.00	\N	\N	\N
P-2026-014	USR-E006	member	2026-06-30 04:43:50.467821+00	30.00	0.30	PMO / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 지표/요건 정리	64220000	2400000.00
P-2026-009	USR-E006	member	2026-06-30 04:43:50.467821+00	10.00	0.10	정책기획 / 2026-08-01~2027-03-31 / 배정 / 구독/정산 정책 요건 검토	64220000	800000.00
P-2026-008	USR-E006	member	2026-06-30 04:43:50.467821+00	10.00	0.10	제안/요건 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 제안 범위 정리	64220000	800000.00
P-2026-012	USR-E006	member	2026-06-30 04:43:50.467821+00	10.00	0.10	운영기획 / 2026-04-01~2026-12-31 / 배정 / 관리자 콘솔 운영 플로우 정리	64220000	800000.00
P-2026-015	USR-E007	support	2026-06-30 04:43:50.467821+00	50.00	0.50	기획지원 / 2026-03-15~2026-11-30 / 배정 / 파트너/계약 자료 정리	38590000	3000000.00
P-2026-014	USR-E007	support	2026-06-30 04:43:50.467821+00	30.00	0.30	PMO 지원 / 2026-02-01~2026-08-31 / 배정 / 회의록/현황판 관리	38590000	1800000.00
P-2026-008	USR-E007	support	2026-06-30 04:43:50.467821+00	20.00	0.20	제안지원 / 2026-02-15~2026-12-31 / 배정 / 공공기관 문서/요건 지원	38590000	1200000.00
P-2026-014	USR-E008	member	2026-06-30 04:43:50.467821+00	30.00	0.30	재무 책임 / 2026-02-01~2026-08-31 / 배정 / 손익/매출 지표 설계	86960000	3000000.00
P-2026-009	USR-E008	member	2026-06-30 04:43:50.467821+00	30.00	0.30	정산 책임 / 2026-08-01~2027-03-31 / 배정 / 정산/회계 기준 검토	86960000	3000000.00
P-2026-015	USR-E008	member	2026-06-30 04:43:50.467821+00	20.00	0.20	계약/매출 검토 / 2026-03-15~2026-11-30 / 배정 / 계약조건/매출 인식 검토	86960000	2000000.00
P-2026-006	USR-E008	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	예산관리 / 2026-01-10~2026-11-30 / 배정 / ERP 리뉴얼 예산 통제	86960000	2000000.00
P-2026-009	USR-E009	member	2026-06-30 04:43:50.467821+00	40.00	0.40	정산 실무 / 2026-08-01~2027-03-31 / 배정 / 결제/정산 업무 규칙 정리	59330000	3200000.00
P-2026-014	USR-E009	member	2026-06-30 04:43:50.467821+00	30.00	0.30	재무 데이터 실무 / 2026-02-01~2026-08-31 / 배정 / 회계/매출 데이터 정리	59330000	2400000.00
P-2026-015	USR-E009	member	2026-06-30 04:43:50.467821+00	20.00	0.20	계약/회계 검토 / 2026-03-15~2026-11-30 / 배정 / 계약서 회계 조건 검토	59330000	1600000.00
P-2026-013	USR-E009	member	2026-06-30 04:43:50.467821+00	10.00	0.10	계약 검토 / 2026-09-01~2027-05-31 / 배정 / 고객사 연동 계약 조건 검토	59330000	800000.00
P-2026-014	USR-E010	support	2026-06-30 04:43:50.467821+00	50.00	0.50	재무지원 / 2026-02-01~2026-08-31 / 배정 / 증빙/마감 데이터 정리	42700000	3000000.00
P-2026-009	USR-E010	support	2026-06-30 04:43:50.467821+00	30.00	0.30	정산지원 / 2026-08-01~2027-03-31 / 배정 / 결제 테스트 정산 검증	42700000	1800000.00
P-2026-015	USR-E010	support	2026-06-30 04:43:50.467821+00	20.00	0.20	계약지원 / 2026-03-15~2026-11-30 / 배정 / 계약 문서/승인 지원	42700000	1200000.00
P-2026-001	USR-E011	member	2026-06-30 04:43:50.467821+00	30.00	0.30	연구소 기술책임 / 2026-01-05~2026-09-30 / 배정 / AI 플랫폼 연구 방향 총괄	122070000	3900000.00
P-2026-002	USR-E011	member	2026-06-30 04:43:50.467821+00	20.00	0.20	기술검토 / 2026-02-01~2026-10-31 / 배정 / 비전 AI 모델 방향 검토	122070000	2600000.00
P-2026-004	USR-E011	member	2026-06-30 04:43:50.467821+00	20.00	0.20	기술검토 / 2026-03-01~2026-12-15 / 배정 / 추천 모델 전략 검토	122070000	2600000.00
P-2026-005	USR-E011	member	2026-06-30 04:43:50.467821+00	20.00	0.20	기술책임 / 2026-07-01~2027-02-28 / 배정 / LLM 자동화 연구 방향 총괄	122070000	2600000.00
P-2026-003	USR-E011	member	2026-06-30 04:43:50.467821+00	10.00	0.10	데이터 전략 검토 / 2025-11-01~2026-04-30 / 배정 / 데이터 레이크 연구 연계	122070000	1300000.00
P-2026-001	USR-E012	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-01-05~2026-09-30 / 배정 / AI 상담 챗봇 플랫폼 PM	92440000	4000000.00
P-2026-005	USR-E012	member	2026-06-30 04:43:50.467821+00	20.00	0.20	LLM 기술검토 / 2026-07-01~2027-02-28 / 배정 / LLM 업무자동화 모델 검토	92440000	2000000.00
P-2026-002	USR-E012	member	2026-06-30 04:43:50.467821+00	20.00	0.20	모델검토 / 2026-02-01~2026-10-31 / 배정 / 비전 AI 모델 품질 검토	92440000	2000000.00
P-2026-014	USR-E012	member	2026-06-30 04:43:50.467821+00	20.00	0.20	AI 지표 자문 / 2026-02-01~2026-08-31 / 배정 / 상담/자동화 KPI 지표 자문	92440000	2000000.00
P-2026-001	USR-E013	member	2026-06-30 04:43:50.467821+00	60.00	0.60	NLP 핵심실무 / 2026-01-05~2026-09-30 / 배정 / 대화 모델/평가셋 개발	64810000	4800000.00
P-2026-005	USR-E013	member	2026-06-30 04:43:50.467821+00	20.00	0.20	프롬프트/평가 / 2026-07-01~2027-02-28 / 배정 / 자동화 프롬프트 평가 지원	64810000	1600000.00
P-2026-004	USR-E013	support	2026-06-30 04:43:50.467821+00	10.00	0.10	모델지원 / 2026-03-01~2026-12-15 / 배정 / 추천 설명 문구/실험 지원	64810000	800000.00
P-2026-002	USR-E013	member	2026-06-30 04:43:50.467821+00	10.00	0.10	라벨링 검토 / 2026-02-01~2026-10-31 / 배정 / 불량 탐지 라벨 기준 검토	64810000	800000.00
P-2026-002	USR-E014	pm	2026-06-30 04:43:50.467821+00	50.00	0.50	PM / 2026-02-01~2026-10-31 / 배정 / 제조 비전 AI PM	57180000	4000000.00
P-2026-001	USR-E014	member	2026-06-30 04:43:50.467821+00	20.00	0.20	AI 모델 연계 / 2026-01-05~2026-09-30 / 배정 / 상담 플랫폼 내 이미지 이슈 연계 검토	57180000	1600000.00
P-2026-004	USR-E014	member	2026-06-30 04:43:50.467821+00	20.00	0.20	모델 실험 / 2026-03-01~2026-12-15 / 배정 / 추천 모델 실험 지원	57180000	1600000.00
P-2026-005	USR-E014	member	2026-06-30 04:43:50.467821+00	10.00	0.10	벤치마크 / 2026-07-01~2027-02-28 / 배정 / LLM/비전 모델 비교 실험	57180000	800000.00
P-2026-005	USR-E015	support	2026-06-30 04:43:50.467821+00	40.00	0.40	연구지원 / 2026-07-01~2027-02-28 / 배정 / LLM 자동화 실험/문서화	40550000	2400000.00
P-2026-001	USR-E015	support	2026-06-30 04:43:50.467821+00	30.00	0.30	데이터/평가 지원 / 2026-01-05~2026-09-30 / 배정 / 챗봇 학습 데이터 정리	40550000	1800000.00
P-2026-002	USR-E015	member	2026-06-30 04:43:50.467821+00	20.00	0.20	데이터라벨링 / 2026-02-01~2026-10-31 / 배정 / 불량 이미지 라벨링 지원	40550000	1200000.00
P-2026-003	USR-E015	member	2026-06-30 04:43:50.467821+00	10.00	0.10	데이터정제 / 2025-11-01~2026-04-30 / 배정 / PoC 데이터 샘플 정리	40550000	600000.00
P-2026-003	USR-E016	pm	2026-06-30 04:43:50.467821+00	30.00	0.30	PM / 2025-11-01~2026-04-30 / 배정 / 데이터 레이크 PoC PM	110920000	3900000.00
P-2026-004	USR-E016	member	2026-06-30 04:43:50.467821+00	30.00	0.30	데이터 책임 / 2026-03-01~2026-12-15 / 배정 / 추천 데이터 구조 검토	110920000	3900000.00
P-2026-014	USR-E016	member	2026-06-30 04:43:50.467821+00	20.00	0.20	BI 데이터 책임 / 2026-02-01~2026-08-31 / 배정 / 경영 KPI 데이터 모델 검토	110920000	2600000.00
P-2026-001	USR-E016	member	2026-06-30 04:43:50.467821+00	20.00	0.20	데이터 전략 검토 / 2026-01-05~2026-09-30 / 배정 / 상담 데이터 수집/품질 기준 검토	110920000	2600000.00
P-2026-004	USR-E017	pm	2026-06-30 04:43:50.467821+00	50.00	0.50	PM / 2026-03-01~2026-12-15 / 배정 / 개인화 추천엔진 PM	81290000	5000000.00
P-2026-003	USR-E017	member	2026-06-30 04:43:50.467821+00	20.00	0.20	분석모델 책임 / 2025-11-01~2026-04-30 / 배정 / PoC 분석 모델 검토	81290000	2000000.00
P-2026-001	USR-E017	member	2026-06-30 04:43:50.467821+00	10.00	0.10	추천/개인화 자문 / 2026-01-05~2026-09-30 / 배정 / 상담 추천 시나리오 자문	81290000	1000000.00
P-2026-014	USR-E017	member	2026-06-30 04:43:50.467821+00	20.00	0.20	성과지표 자문 / 2026-02-01~2026-08-31 / 배정 / 실험/전환율 KPI 설계	81290000	2000000.00
P-2026-003	USR-E018	member	2026-06-30 04:43:50.467821+00	40.00	0.40	ML 실무 / 2025-11-01~2026-04-30 / 배정 / 피처/모델 서빙 PoC	62660000	3200000.00
P-2026-004	USR-E018	member	2026-06-30 04:43:50.467821+00	30.00	0.30	추천모델 실무 / 2026-03-01~2026-12-15 / 배정 / 추천 모델 튜닝	62660000	2400000.00
P-2026-001	USR-E018	support	2026-06-30 04:43:50.467821+00	10.00	0.10	모델서빙 지원 / 2026-01-05~2026-09-30 / 배정 / 챗봇 모델 서빙 연계	62660000	800000.00
P-2026-005	USR-E018	member	2026-06-30 04:43:50.467821+00	20.00	0.20	MLOps 연계 / 2026-07-01~2027-02-28 / 배정 / 자동화 모델 배포 지원	62660000	1600000.00
P-2026-003	USR-E019	member	2026-06-30 04:43:50.467821+00	40.00	0.40	데이터분석 실무 / 2025-11-01~2026-04-30 / 배정 / 분석 쿼리/BI 시각화	64030000	3200000.00
P-2026-014	USR-E019	member	2026-06-30 04:43:50.467821+00	30.00	0.30	경영 BI 실무 / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 지표 구현	64030000	2400000.00
P-2026-004	USR-E019	member	2026-06-30 04:43:50.467821+00	20.00	0.20	실험분석 / 2026-03-01~2026-12-15 / 배정 / 추천 A/B 테스트 분석	64030000	1600000.00
P-2026-015	USR-E019	member	2026-06-30 04:43:50.467821+00	10.00	0.10	영업 데이터 분석 / 2026-03-15~2026-11-30 / 배정 / 파트너 영업지표 지원	64030000	800000.00
P-2026-003	USR-E020	member	2026-06-30 04:43:50.467821+00	50.00	0.50	데이터정제 / 2025-11-01~2026-04-30 / 배정 / 데이터 레이크 샘플 정리	38400000	3000000.00
P-2026-014	USR-E020	support	2026-06-30 04:43:50.467821+00	30.00	0.30	대시보드 데이터 지원 / 2026-02-01~2026-08-31 / 배정 / 경영 데이터 정합성 확인	38400000	1800000.00
P-2026-004	USR-E020	support	2026-06-30 04:43:50.467821+00	20.00	0.20	분석지원 / 2026-03-01~2026-12-15 / 배정 / 추천 데이터 라벨/집계 지원	38400000	1200000.00
P-2026-005	USR-E021	pm	2026-06-30 04:43:50.467821+00	30.00	0.30	PM / 2026-07-01~2027-02-28 / 배정 / LLM 업무자동화 연구 PM	108770000	3900000.00
P-2026-001	USR-E021	member	2026-06-30 04:43:50.467821+00	20.00	0.20	플랫폼 책임 / 2026-01-05~2026-09-30 / 배정 / 챗봇 플랫폼 아키텍처 검토	108770000	2600000.00
P-2026-006	USR-E021	member	2026-06-30 04:43:50.467821+00	20.00	0.20	아키텍처 자문 / 2026-01-10~2026-11-30 / 배정 / ERP 백엔드 구조 자문	108770000	2600000.00
P-2026-010	USR-E021	member	2026-06-30 04:43:50.467821+00	20.00	0.20	MLOps/클라우드 자문 / 2026-01-20~2026-10-15 / 배정 / 클라우드 전환 방향 검토	108770000	2600000.00
P-2026-013	USR-E021	member	2026-06-30 04:43:50.467821+00	10.00	0.10	플랫폼 연계 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 구조 자문	108770000	1300000.00
P-2026-005	USR-E022	member	2026-06-30 04:43:50.467821+00	40.00	0.40	기술리드 / 2026-07-01~2027-02-28 / 배정 / 업무자동화 시스템 아키텍처	79140000	4000000.00
P-2026-013	USR-E022	member	2026-06-30 04:43:50.467821+00	20.00	0.20	보안/API 설계 / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 보안 구조 검토	79140000	2000000.00
P-2026-006	USR-E022	member	2026-06-30 04:43:50.467821+00	20.00	0.20	아키텍처 검토 / 2026-01-10~2026-11-30 / 배정 / ERP MSA 전환 구조 검토	79140000	2000000.00
P-2026-010	USR-E022	member	2026-06-30 04:43:50.467821+00	20.00	0.20	운영 아키텍처 / 2026-01-20~2026-10-15 / 배정 / 배포/운영 구조 검토	79140000	2000000.00
P-2026-005	USR-E023	member	2026-06-30 04:43:50.467821+00	50.00	0.50	플랫폼 실무 / 2026-07-01~2027-02-28 / 배정 / Agent/서비스 구조 구현	60510000	4000000.00
P-2026-001	USR-E023	member	2026-06-30 04:43:50.467821+00	20.00	0.20	플랫폼 연계 / 2026-01-05~2026-09-30 / 배정 / 챗봇 API/서비스 연계	60510000	1600000.00
P-2026-006	USR-E023	support	2026-06-30 04:43:50.467821+00	20.00	0.20	성능개선 지원 / 2026-01-10~2026-11-30 / 배정 / 백엔드 성능 검토 지원	60510000	1600000.00
P-2026-010	USR-E023	support	2026-06-30 04:43:50.467821+00	10.00	0.10	모니터링 지원 / 2026-01-20~2026-10-15 / 배정 / 관측성 항목 검토	60510000	800000.00
P-2026-005	USR-E024	member	2026-06-30 04:43:50.467821+00	40.00	0.40	MLOps 실무 / 2026-07-01~2027-02-28 / 배정 / 모델 배포 파이프라인	61880000	3200000.00
P-2026-010	USR-E024	member	2026-06-30 04:43:50.467821+00	30.00	0.30	CI/CD 연계 / 2026-01-20~2026-10-15 / 배정 / MLOps 배포 자동화 연계	61880000	2400000.00
P-2026-001	USR-E024	support	2026-06-30 04:43:50.467821+00	20.00	0.20	모델 배포 지원 / 2026-01-05~2026-09-30 / 배정 / 챗봇 모델 운영 파이프라인	61880000	1600000.00
P-2026-003	USR-E024	support	2026-06-30 04:43:50.467821+00	10.00	0.10	데이터 파이프라인 지원 / 2025-11-01~2026-04-30 / 배정 / PoC 파이프라인 검토	61880000	800000.00
P-2026-005	USR-E025	support	2026-06-30 04:43:50.467821+00	40.00	0.40	연구지원 / 2026-07-01~2027-02-28 / 배정 / 실험관리/문서화	45250000	2400000.00
P-2026-003	USR-E025	support	2026-06-30 04:43:50.467821+00	20.00	0.20	데이터지원 / 2025-11-01~2026-04-30 / 배정 / 데이터 정제/보고 지원	45250000	1200000.00
P-2026-001	USR-E025	support	2026-06-30 04:43:50.467821+00	20.00	0.20	평가지원 / 2026-01-05~2026-09-30 / 배정 / 챗봇 테스트 시나리오 지원	45250000	1200000.00
P-2026-011	USR-E025	support	2026-06-30 04:43:50.467821+00	20.00	0.20	테스트지원 / 2025-10-01~2026-03-31 / 배정 / 자동화 테스트 데이터 지원	45250000	1200000.00
P-2026-006	USR-E026	developer	2026-06-30 04:43:50.467821+00	20.00	0.20	개발본부 기술책임 / 2026-01-10~2026-11-30 / 배정 / ERP 리뉴얼 기술 방향 총괄	124620000	2600000.00
P-2026-008	USR-E026	developer	2026-06-30 04:43:50.467821+00	20.00	0.20	개발본부 기술책임 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 고도화 기술 검토	124620000	2600000.00
P-2026-010	USR-E026	developer	2026-06-30 04:43:50.467821+00	20.00	0.20	개발본부 기술책임 / 2026-01-20~2026-10-15 / 배정 / 클라우드 전환 총괄 검토	124620000	2600000.00
P-2026-012	USR-E026	developer	2026-06-30 04:43:50.467821+00	20.00	0.20	개발본부 기술책임 / 2026-04-01~2026-12-31 / 배정 / 관리자 콘솔 구조 검토	124620000	2600000.00
P-2026-013	USR-E026	developer	2026-06-30 04:43:50.467821+00	20.00	0.20	개발본부 기술책임 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 기술 총괄	124620000	2600000.00
P-2026-006	USR-E027	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-01-10~2026-11-30 / 배정 / SaaS ERP 백엔드 리뉴얼 PM	85990000	4000000.00
P-2026-013	USR-E027	member	2026-06-30 04:43:50.467821+00	30.00	0.30	공동PM / 2026-09-01~2027-05-31 / 배정 / 고객사 API 게이트웨이 공동 책임	85990000	3000000.00
P-2026-009	USR-E027	member	2026-06-30 04:43:50.467821+00	20.00	0.20	백엔드 책임 / 2026-08-01~2027-03-31 / 배정 / 결제/정산 백엔드 구조 검토	85990000	2000000.00
P-2026-010	USR-E027	member	2026-06-30 04:43:50.467821+00	10.00	0.10	배포검토 / 2026-01-20~2026-10-15 / 배정 / 백엔드 배포 전환 검토	85990000	1000000.00
P-2026-006	USR-E028	member	2026-06-30 04:43:50.467821+00	50.00	0.50	백엔드 핵심실무 / 2026-01-10~2026-11-30 / 배정 / ERP 핵심 API 개발	58360000	4000000.00
P-2026-013	USR-E028	developer	2026-06-30 04:43:50.467821+00	30.00	0.30	API 개발 / 2026-09-01~2027-05-31 / 배정 / 고객 연동 API 구현	58360000	2400000.00
P-2026-001	USR-E001	sponsor	2026-06-30 04:43:50.467821+00	20.00	0.20	Executive Sponsor / 2026-01-05~2026-09-30 / 배정 / 전사 핵심 AI 과제 경영 후원	180000000	3600000.00
P-2026-006	USR-E001	sponsor	2026-06-30 04:43:50.467821+00	20.00	0.20	Executive Sponsor / 2026-01-10~2026-11-30 / 배정 / 주요 매출 과제 의사결정	180000000	3600000.00
P-2026-013	USR-E001	sponsor	2026-06-30 04:43:50.467821+00	20.00	0.20	Executive Sponsor / 2026-09-01~2027-05-31 / 배정 / 전략 고객 연동 과제 후원	180000000	3600000.00
P-2026-014	USR-E001	sponsor	2026-06-30 04:43:50.467821+00	20.00	0.20	Executive Sponsor / 2026-02-01~2026-08-31 / 배정 / 경영 KPI 총괄 검토	180000000	3600000.00
P-2026-015	USR-E001	sponsor	2026-06-30 04:43:50.467821+00	20.00	0.20	Executive Sponsor / 2026-03-15~2026-11-30 / 배정 / 파트너/계약 체계 의사결정	180000000	3600000.00
P-2026-014	USR-E002	manager	2026-06-30 04:43:50.467821+00	30.00	0.30	경영관리 책임 / 2026-02-01~2026-08-31 / 배정 / 본부 간 운영/보고 체계 총괄	78740000	3000000.00
P-2026-015	USR-E002	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	계약관리 검토 / 2026-03-15~2026-11-30 / 배정 / 계약 프로세스 운영 검토	78740000	2000000.00
P-2026-010	USR-E002	member	2026-06-30 04:43:50.467821+00	20.00	0.20	운영 리스크 검토 / 2026-01-20~2026-10-15 / 배정 / 운영 전환 리스크 관리	78740000	2000000.00
P-2026-013	USR-E002	support	2026-06-30 04:43:50.467821+00	20.00	0.20	대외협력 지원 / 2026-09-01~2027-05-31 / 배정 / 고객사 협업 프로세스 조율	78740000	2000000.00
P-2026-001	USR-E002	member	2026-06-30 04:43:50.467821+00	10.00	0.10	사업성 검토 / 2026-01-05~2026-09-30 / 배정 / AI 플랫폼 사업성 검토	78740000	1000000.00
P-2026-014	USR-E003	member	2026-06-30 04:43:50.467821+00	30.00	0.30	조직/인력 책임 / 2026-02-01~2026-08-31 / 배정 / 인력 KPI와 조직 데이터 기준 수립	89110000	3000000.00
P-2026-015	USR-E003	member	2026-06-30 04:43:50.467821+00	20.00	0.20	권한/조직 검토 / 2026-03-15~2026-11-30 / 배정 / 파트너 업무 권한 체계 검토	89110000	2000000.00
P-2026-006	USR-E003	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	변경관리 / 2026-01-10~2026-11-30 / 배정 / ERP 전환 조직 영향 관리	89110000	2000000.00
P-2026-010	USR-E003	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	변경관리 / 2026-01-20~2026-10-15 / 배정 / 클라우드 전환 교육/전파	89110000	2000000.00
P-2026-005	USR-E003	member	2026-06-30 04:43:50.467821+00	10.00	0.10	교육체계 검토 / 2026-07-01~2027-02-28 / 배정 / 업무자동화 도입 교육 검토	89110000	1000000.00
P-2026-014	USR-E004	member	2026-06-30 04:43:50.467821+00	40.00	0.40	HR 실무 / 2026-02-01~2026-08-31 / 배정 / 인력 현황/교육 지표 정리	61480000	3200000.00
P-2026-006	USR-E004	manager	2026-06-30 04:43:50.467821+00	30.00	0.30	변경관리 실무 / 2026-01-10~2026-11-30 / 배정 / ERP 전환 교육자료 정리	61480000	2400000.00
P-2026-010	USR-E004	member	2026-06-30 04:43:50.467821+00	20.00	0.20	교육 운영 / 2026-01-20~2026-10-15 / 배정 / DevOps 전환 교육 운영	61480000	1600000.00
P-2026-005	USR-E004	support	2026-06-30 04:43:50.467821+00	10.00	0.10	교육 지원 / 2026-07-01~2027-02-28 / 배정 / AI 자동화 사용 가이드 지원	61480000	800000.00
P-2026-014	USR-E005	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 구축 총괄	91850000	4000000.00
P-2026-015	USR-E005	member	2026-06-30 04:43:50.467821+00	30.00	0.30	기획 책임 / 2026-03-15~2026-11-30 / 배정 / 계약관리 프로세스 설계	91850000	3000000.00
P-2026-001	USR-E005	member	2026-06-30 04:43:50.467821+00	10.00	0.10	사업기획 검토 / 2026-01-05~2026-09-30 / 배정 / AI 상담 플랫폼 ROI 검토	91850000	1000000.00
P-2026-006	USR-E005	member	2026-06-30 04:43:50.467821+00	10.00	0.10	PMO / 2026-01-10~2026-11-30 / 배정 / ERP 리뉴얼 일정/범위 관리	91850000	1000000.00
P-2026-013	USR-E005	member	2026-06-30 04:43:50.467821+00	10.00	0.10	PMO / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 고객 일정 관리	91850000	1000000.00
P-2026-015	USR-E006	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-03-15~2026-11-30 / 배정 / 파트너 영업/계약관리 총괄	64220000	3200000.00
P-2026-009	USR-E028	support	2026-06-30 04:43:50.467821+00	20.00	0.20	결제 API 지원 / 2026-08-01~2027-03-31 / 배정 / 정산/결제 API 연계	58360000	1600000.00
P-2026-006	USR-E029	member	2026-06-30 04:43:50.467821+00	40.00	0.40	백엔드 실무 / 2026-01-10~2026-11-30 / 배정 / ERP 배치/서비스 개발	59730000	3200000.00
P-2026-009	USR-E029	member	2026-06-30 04:43:50.467821+00	30.00	0.30	정산 백엔드 / 2026-08-01~2027-03-31 / 배정 / 구독 정산 배치 개발	59730000	2400000.00
P-2026-013	USR-E029	member	2026-06-30 04:43:50.467821+00	20.00	0.20	API 연동 / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 백엔드 연동	59730000	1600000.00
P-2026-012	USR-E029	manager	2026-06-30 04:43:50.467821+00	10.00	0.10	관리 API 지원 / 2026-04-01~2026-12-31 / 배정 / 관리자 콘솔 API 지원	59730000	800000.00
P-2026-006	USR-E030	member	2026-06-30 04:43:50.467821+00	50.00	0.50	주니어 백엔드 / 2026-01-10~2026-11-30 / 배정 / ERP API 개발/테스트	43100000	3000000.00
P-2026-013	USR-E030	developer	2026-06-30 04:43:50.467821+00	30.00	0.30	API 개발지원 / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 테스트 API 지원	43100000	1800000.00
P-2026-011	USR-E030	support	2026-06-30 04:43:50.467821+00	20.00	0.20	테스트지원 / 2025-10-01~2026-03-31 / 배정 / API 테스트 스크립트 지원	43100000	1200000.00
P-2026-013	USR-E031	member	2026-06-30 04:43:50.467821+00	50.00	0.50	API 핵심실무 / 2026-09-01~2027-05-31 / 배정 / 고객사 API 게이트웨이 개발	44470000	3000000.00
P-2026-006	USR-E031	member	2026-06-30 04:43:50.467821+00	20.00	0.20	API 연계 / 2026-01-10~2026-11-30 / 배정 / ERP API 연동	44470000	1200000.00
P-2026-009	USR-E031	member	2026-06-30 04:43:50.467821+00	20.00	0.20	결제 API 연계 / 2026-08-01~2027-03-31 / 배정 / 구독결제 연동 API	44470000	1200000.00
P-2026-015	USR-E031	support	2026-06-30 04:43:50.467821+00	10.00	0.10	계약 API 지원 / 2026-03-15~2026-11-30 / 배정 / 파트너 계약 API 지원	44470000	600000.00
P-2026-009	USR-E032	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-08-01~2027-03-31 / 배정 / 구독결제/정산 시스템 PM	92840000	4000000.00
P-2026-006	USR-E032	member	2026-06-30 04:43:50.467821+00	30.00	0.30	DB 책임 / 2026-01-10~2026-11-30 / 배정 / ERP DB 설계/성능	92840000	3000000.00
P-2026-013	USR-E032	member	2026-06-30 04:43:50.467821+00	20.00	0.20	DB/API 스키마 / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 데이터 모델	92840000	2000000.00
P-2026-014	USR-E032	member	2026-06-30 04:43:50.467821+00	10.00	0.10	원가/정산 데이터 / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 원가 데이터	92840000	1000000.00
P-2026-012	USR-E033	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-04-01~2026-12-31 / 배정 / 통합 관리자 콘솔 PM	85210000	4000000.00
P-2026-008	USR-E033	member	2026-06-30 04:43:50.467821+00	30.00	0.30	프론트엔드 책임 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 UI 구조	85210000	3000000.00
P-2026-014	USR-E033	member	2026-06-30 04:43:50.467821+00	20.00	0.20	대시보드 UI 책임 / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 UI 구조	85210000	2000000.00
P-2026-015	USR-E033	member	2026-06-30 04:43:50.467821+00	10.00	0.10	CRM UI 검토 / 2026-03-15~2026-11-30 / 배정 / 계약관리 화면 흐름 검토	85210000	1000000.00
P-2026-008	USR-E034	member	2026-06-30 04:43:50.467821+00	50.00	0.50	프론트엔드 핵심실무 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 화면 개발	57580000	4000000.00
P-2026-012	USR-E034	developer	2026-06-30 04:43:50.467821+00	30.00	0.30	관리 콘솔 개발 / 2026-04-01~2026-12-31 / 배정 / 관리자 화면 컴포넌트	57580000	2400000.00
P-2026-014	USR-E034	support	2026-06-30 04:43:50.467821+00	10.00	0.10	대시보드 UI 지원 / 2026-02-01~2026-08-31 / 배정 / KPI 화면 지원	57580000	800000.00
P-2026-015	USR-E034	manager	2026-06-30 04:43:50.467821+00	10.00	0.10	계약관리 UI 지원 / 2026-03-15~2026-11-30 / 배정 / 파트너 화면 지원	57580000	800000.00
P-2026-012	USR-E035	member	2026-06-30 04:43:50.467821+00	50.00	0.50	UI 핵심실무 / 2026-04-01~2026-12-31 / 배정 / 디자인시스템/관리 UI	58950000	4000000.00
P-2026-008	USR-E035	member	2026-06-30 04:43:50.467821+00	30.00	0.30	웹접근성 UI / 2026-02-15~2026-12-31 / 배정 / 공공 포털 UI 개선	58950000	2400000.00
P-2026-014	USR-E035	support	2026-06-30 04:43:50.467821+00	10.00	0.10	대시보드 UI 지원 / 2026-02-01~2026-08-31 / 배정 / 경영 화면 컴포넌트 지원	58950000	800000.00
P-2026-015	USR-E035	support	2026-06-30 04:43:50.467821+00	10.00	0.10	계약 UI 지원 / 2026-03-15~2026-11-30 / 배정 / 계약 플로우 화면 지원	58950000	800000.00
P-2026-012	USR-E036	developer	2026-06-30 04:43:50.467821+00	50.00	0.50	웹 개발 / 2026-04-01~2026-12-31 / 배정 / 통합 관리자 콘솔 개발	42320000	3000000.00
P-2026-008	USR-E036	developer	2026-06-30 04:43:50.467821+00	30.00	0.30	프론트엔드 개발 / 2026-02-15~2026-12-31 / 배정 / 민원 포털 화면 개발	42320000	1800000.00
P-2026-015	USR-E036	support	2026-06-30 04:43:50.467821+00	10.00	0.10	화면 지원 / 2026-03-15~2026-11-30 / 배정 / 계약관리 화면 지원	42320000	600000.00
P-2026-011	USR-E036	support	2026-06-30 04:43:50.467821+00	10.00	0.10	테스트 화면 지원 / 2025-10-01~2026-03-31 / 배정 / 테스트 현황 화면 지원	42320000	600000.00
P-2026-008	USR-E037	member	2026-06-30 04:43:50.467821+00	50.00	0.50	퍼블리싱 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 웹접근성/퍼블리싱	43690000	3000000.00
P-2026-012	USR-E037	support	2026-06-30 04:43:50.467821+00	20.00	0.20	디자인시스템 지원 / 2026-04-01~2026-12-31 / 배정 / 관리 콘솔 UI 마크업	43690000	1200000.00
P-2026-014	USR-E037	member	2026-06-30 04:43:50.467821+00	20.00	0.20	대시보드 마크업 / 2026-02-01~2026-08-31 / 배정 / 경영 대시보드 화면 마크업	43690000	1200000.00
P-2026-015	USR-E037	manager	2026-06-30 04:43:50.467821+00	10.00	0.10	계약관리 마크업 / 2026-03-15~2026-11-30 / 배정 / 파트너 화면 마크업	43690000	600000.00
P-2026-008	USR-E038	member	2026-06-30 04:43:50.467821+00	40.00	0.40	UX 책임 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 UX 총괄	83060000	4000000.00
P-2026-012	USR-E038	member	2026-06-30 04:43:50.467821+00	30.00	0.30	UX 리드 / 2026-04-01~2026-12-31 / 배정 / 관리자 콘솔 사용 흐름 설계	83060000	3000000.00
P-2026-007	USR-E038	member	2026-06-30 04:43:50.467821+00	20.00	0.20	모바일 UX 검토 / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 UX 검토	83060000	2000000.00
P-2026-015	USR-E038	member	2026-06-30 04:43:50.467821+00	10.00	0.10	계약 플로우 UX / 2026-03-15~2026-11-30 / 배정 / 파트너 계약 승인 흐름	83060000	1000000.00
P-2026-007	USR-E039	pm	2026-06-30 04:43:50.467821+00	50.00	0.50	PM / 2025-12-01~2026-05-31 / 배정 / 모바일 현장관리 앱 PM	93430000	5000000.00
P-2026-010	USR-E039	member	2026-06-30 04:43:50.467821+00	20.00	0.20	릴리즈 책임 / 2026-01-20~2026-10-15 / 배정 / 모바일 배포/운영 전환 조율	93430000	2000000.00
P-2026-008	USR-E039	member	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일웹 검토 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 모바일 대응 검토	93430000	1000000.00
P-2026-012	USR-E039	manager	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일 관리 검토 / 2026-04-01~2026-12-31 / 배정 / 관리 콘솔 모바일 대응 검토	93430000	1000000.00
P-2026-015	USR-E039	member	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일 승인 검토 / 2026-03-15~2026-11-30 / 배정 / 계약 승인 모바일 플로우	93430000	1000000.00
P-2026-007	USR-E040	member	2026-06-30 04:43:50.467821+00	60.00	0.60	iOS 핵심실무 / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 iOS 개발	56800000	4800000.00
P-2026-012	USR-E040	support	2026-06-30 04:43:50.467821+00	20.00	0.20	모바일 대응 지원 / 2026-04-01~2026-12-31 / 배정 / 관리 콘솔 모바일 화면 검토	56800000	1600000.00
P-2026-010	USR-E040	support	2026-06-30 04:43:50.467821+00	10.00	0.10	배포지원 / 2026-01-20~2026-10-15 / 배정 / iOS 배포 자동화 지원	56800000	800000.00
P-2026-015	USR-E040	support	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일 승인 지원 / 2026-03-15~2026-11-30 / 배정 / 계약 승인 앱 검토	56800000	800000.00
P-2026-007	USR-E041	member	2026-06-30 04:43:50.467821+00	60.00	0.60	Android 핵심실무 / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 Android 개발	58170000	4800000.00
P-2026-010	USR-E041	support	2026-06-30 04:43:50.467821+00	20.00	0.20	배포지원 / 2026-01-20~2026-10-15 / 배정 / Android 배포 자동화 지원	58170000	1600000.00
P-2026-008	USR-E041	member	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일웹 검토 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 모바일 검토	58170000	800000.00
P-2026-012	USR-E041	manager	2026-06-30 04:43:50.467821+00	10.00	0.10	관리자 화면 검토 / 2026-04-01~2026-12-31 / 배정 / 관리 콘솔 모바일 대응	58170000	800000.00
P-2026-007	USR-E042	developer	2026-06-30 04:43:50.467821+00	50.00	0.50	Flutter 개발 / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 공통 화면	41540000	3000000.00
P-2026-008	USR-E042	support	2026-06-30 04:43:50.467821+00	20.00	0.20	모바일 화면 지원 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 모바일 UI	41540000	1200000.00
P-2026-012	USR-E042	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	관리자 화면 지원 / 2026-04-01~2026-12-31 / 배정 / 관리 콘솔 반응형 지원	41540000	1200000.00
P-2026-011	USR-E042	support	2026-06-30 04:43:50.467821+00	10.00	0.10	테스트 앱 지원 / 2025-10-01~2026-03-31 / 배정 / 테스트 플랫폼 모바일 확인	41540000	600000.00
P-2026-007	USR-E043	qa	2026-06-30 04:43:50.467821+00	40.00	0.40	모바일 QA / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 테스트	42910000	2400000.00
P-2026-011	USR-E043	qa	2026-06-30 04:43:50.467821+00	30.00	0.30	QA 실무 / 2025-10-01~2026-03-31 / 배정 / 자동화 테스트 케이스 작성	42910000	1800000.00
P-2026-008	USR-E043	qa	2026-06-30 04:43:50.467821+00	20.00	0.20	모바일 QA 지원 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 모바일 검증	42910000	1200000.00
P-2026-010	USR-E043	member	2026-06-30 04:43:50.467821+00	10.00	0.10	릴리즈 검증 / 2026-01-20~2026-10-15 / 배정 / 모바일 릴리즈 체크	42910000	600000.00
P-2026-010	USR-E044	pm	2026-06-30 04:43:50.467821+00	40.00	0.40	PM / 2026-01-20~2026-10-15 / 배정 / DevOps 클라우드 전환 PM	91280000	4000000.00
P-2026-011	USR-E044	pm	2026-06-30 04:43:50.467821+00	30.00	0.30	PM / 2025-10-01~2026-03-31 / 배정 / 품질자동화 테스트 플랫폼 PM	91280000	3000000.00
P-2026-006	USR-E044	qa	2026-06-30 04:43:50.467821+00	10.00	0.10	QA 전략 / 2026-01-10~2026-11-30 / 배정 / ERP QA 전략 검토	91280000	1000000.00
P-2026-008	USR-E044	qa	2026-06-30 04:43:50.467821+00	10.00	0.10	QA 전략 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 품질 기준 검토	91280000	1000000.00
P-2026-013	USR-E044	qa	2026-06-30 04:43:50.467821+00	10.00	0.10	QA 전략 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 품질 기준 검토	91280000	1000000.00
P-2026-010	USR-E045	devops	2026-06-30 04:43:50.467821+00	50.00	0.50	DevOps 핵심실무 / 2026-01-20~2026-10-15 / 배정 / Kubernetes/CI/CD 전환	63650000	4000000.00
P-2026-006	USR-E045	support	2026-06-30 04:43:50.467821+00	20.00	0.20	배포지원 / 2026-01-10~2026-11-30 / 배정 / ERP 배포 파이프라인	63650000	1600000.00
P-2026-013	USR-E045	support	2026-06-30 04:43:50.467821+00	20.00	0.20	배포지원 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 배포	63650000	1600000.00
P-2026-005	USR-E045	support	2026-06-30 04:43:50.467821+00	10.00	0.10	MLOps 지원 / 2026-07-01~2027-02-28 / 배정 / LLM 자동화 배포 지원	63650000	800000.00
P-2026-011	USR-E046	qa	2026-06-30 04:43:50.467821+00	50.00	0.50	QA 핵심실무 / 2025-10-01~2026-03-31 / 배정 / 테스트 자동화 플랫폼 구현	56020000	4000000.00
P-2026-008	USR-E046	qa	2026-06-30 04:43:50.467821+00	20.00	0.20	QA 지원 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 결함 분석	56020000	1600000.00
P-2026-006	USR-E046	qa	2026-06-30 04:43:50.467821+00	20.00	0.20	QA 지원 / 2026-01-10~2026-11-30 / 배정 / ERP 회귀 테스트	56020000	1600000.00
P-2026-013	USR-E046	qa	2026-06-30 04:43:50.467821+00	10.00	0.10	API QA / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 테스트	56020000	800000.00
P-2026-011	USR-E047	member	2026-06-30 04:43:50.467821+00	50.00	0.50	테스트자동화 / 2025-10-01~2026-03-31 / 배정 / API/회귀 테스트 스크립트	39390000	3000000.00
P-2026-008	USR-E047	member	2026-06-30 04:43:50.467821+00	20.00	0.20	자동화 테스트 / 2026-02-15~2026-12-31 / 배정 / 공공 포털 테스트 스크립트	39390000	1200000.00
P-2026-012	USR-E047	manager	2026-06-30 04:43:50.467821+00	20.00	0.20	관리 콘솔 테스트 / 2026-04-01~2026-12-31 / 배정 / 관리자 화면 테스트	39390000	1200000.00
P-2026-007	USR-E047	member	2026-06-30 04:43:50.467821+00	10.00	0.10	모바일 테스트 / 2025-12-01~2026-05-31 / 배정 / 현장관리 앱 자동화 테스트	39390000	600000.00
P-2026-010	USR-E048	member	2026-06-30 04:43:50.467821+00	50.00	0.50	클라우드 운영 / 2026-01-20~2026-10-15 / 배정 / 클라우드 배포/모니터링	40760000	3000000.00
P-2026-006	USR-E048	support	2026-06-30 04:43:50.467821+00	20.00	0.20	운영지원 / 2026-01-10~2026-11-30 / 배정 / ERP 운영 환경 구성	40760000	1200000.00
P-2026-013	USR-E048	support	2026-06-30 04:43:50.467821+00	20.00	0.20	운영지원 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 운영 구성	40760000	1200000.00
P-2026-011	USR-E048	support	2026-06-30 04:43:50.467821+00	10.00	0.10	운영지원 / 2025-10-01~2026-03-31 / 배정 / 테스트 플랫폼 운영 구성	40760000	600000.00
P-2026-010	USR-E049	member	2026-06-30 04:43:50.467821+00	30.00	0.30	보안/인프라 책임 / 2026-01-20~2026-10-15 / 배정 / 클라우드 보안/인프라 설계	89130000	3000000.00
P-2026-013	USR-E049	member	2026-06-30 04:43:50.467821+00	30.00	0.30	보안 책임 / 2026-09-01~2027-05-31 / 배정 / API 게이트웨이 보안 설계	89130000	3000000.00
P-2026-006	USR-E049	member	2026-06-30 04:43:50.467821+00	20.00	0.20	인프라 검토 / 2026-01-10~2026-11-30 / 배정 / ERP 인프라 구조 검토	89130000	2000000.00
P-2026-009	USR-E049	member	2026-06-30 04:43:50.467821+00	10.00	0.10	보안 검토 / 2026-08-01~2027-03-31 / 배정 / 결제/정산 보안 검토	89130000	1000000.00
P-2026-011	USR-E049	member	2026-06-30 04:43:50.467821+00	10.00	0.10	보안 테스트 / 2025-10-01~2026-03-31 / 배정 / 테스트 플랫폼 보안 점검	89130000	1000000.00
P-2026-010	USR-E050	member	2026-06-30 04:43:50.467821+00	40.00	0.40	SRE / 2026-01-20~2026-10-15 / 배정 / 관측성/운영 안정화	61500000	3200000.00
P-2026-006	USR-E050	support	2026-06-30 04:43:50.467821+00	20.00	0.20	성능/운영 지원 / 2026-01-10~2026-11-30 / 배정 / ERP 성능 모니터링	61500000	1600000.00
P-2026-013	USR-E050	support	2026-06-30 04:43:50.467821+00	20.00	0.20	성능/운영 지원 / 2026-09-01~2027-05-31 / 배정 / 게이트웨이 트래픽 모니터링	61500000	1600000.00
P-2026-011	USR-E050	support	2026-06-30 04:43:50.467821+00	10.00	0.10	운영지원 / 2025-10-01~2026-03-31 / 배정 / 테스트 플랫폼 관측성	61500000	800000.00
P-2026-007	USR-E050	support	2026-06-30 04:43:50.467821+00	10.00	0.10	앱 운영지원 / 2025-12-01~2026-05-31 / 배정 / 모바일 앱 운영 지표	61500000	800000.00
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.projects (project_id, name, status, pm_user_id, created_at, description) FROM stdin;
PJT-GUARD-101950	Protected API Guard Smoke	active	USR-a346f5d41279	2026-06-30 01:19:51.611621+00	\N
P-2026-001	AI 고객상담 챗봇 플랫폼	active	USR-E012	2026-06-30 02:25:02.720936+00	고객 응대 자동화와 상담 품질 지표 개선 | 담당조직: 연구소 / AI연구팀 | 우선순위: 높음 | 매출배분: 850,000,000원 | 주요기술: LLM, NLP, RAG
P-2026-002	제조 불량 탐지 비전 AI	active	USR-E014	2026-06-30 02:25:02.720936+00	제조 라인의 이미지 기반 불량 탐지 모델 개발 | 담당조직: 연구소 / AI연구팀 | 우선순위: 높음 | 매출배분: 700,000,000원 | 주요기술: Vision AI, Deep Learning, Edge
P-2026-003	데이터 레이크 분석 PoC	completed	USR-E016	2026-06-30 02:25:02.720936+00	고객 데이터 통합 분석 환경의 PoC 구축 | 담당조직: 연구소 / 데이터연구팀 | 우선순위: 보통 | 매출배분: 450,000,000원 | 주요기술: Data Lake, SQL, BI
P-2026-004	개인화 추천엔진 고도화	active	USR-E017	2026-06-30 02:25:02.720936+00	커머스 추천 정확도와 전환율 개선 | 담당조직: 연구소 / 데이터연구팀 | 우선순위: 높음 | 매출배분: 650,000,000원 | 주요기술: Recommendation, ML, AB Test
P-2026-005	LLM 업무자동화 연구	planned	USR-E021	2026-06-30 02:25:02.720936+00	사내외 반복 업무 자동화 기술 검증 | 담당조직: 연구소 / 플랫폼R&D팀 | 우선순위: 보통 | 매출배분: 550,000,000원 | 주요기술: LLM, Agent, MLOps
P-2026-006	SaaS ERP 백엔드 리뉴얼	active	USR-E027	2026-06-30 02:25:02.720936+00	노후 ERP 백엔드 구조를 클라우드 친화형으로 개편 | 담당조직: 개발본부 / 백엔드팀 | 우선순위: 높음 | 매출배분: 900,000,000원 | 주요기술: Spring, MSA, PostgreSQL
P-2026-007	모바일 현장관리 앱	completed	USR-E039	2026-06-30 02:25:02.720936+00	현장 작업자용 모바일 업무 앱 구축 | 담당조직: 개발본부 / 모바일팀 | 우선순위: 보통 | 매출배분: 700,000,000원 | 주요기술: iOS, Android, Flutter
P-2026-008	공공기관 민원 포털 고도화	active	USR-E033	2026-06-30 02:25:02.720936+00	공공 민원 포털의 UX와 처리 프로세스 고도화 | 담당조직: 개발본부 / 프론트엔드팀 | 우선순위: 높음 | 매출배분: 850,000,000원 | 주요기술: React, Spring, Accessibility
P-2026-009	구독결제/정산 시스템	planned	USR-E032	2026-06-30 02:25:02.720936+00	구독형 서비스 결제와 정산 자동화 | 담당조직: 개발본부 / 백엔드팀 | 우선순위: 높음 | 매출배분: 600,000,000원 | 주요기술: Payment, Billing, API
P-2026-010	DevOps 클라우드 전환	active	USR-E044	2026-06-30 02:25:02.720936+00	배포 자동화와 인프라 운영 안정성 개선 | 담당조직: 개발본부 / QA/DevOps팀 | 우선순위: 높음 | 매출배분: 600,000,000원 | 주요기술: Kubernetes, CI/CD, Observability
P-2026-011	품질자동화 테스트 플랫폼	completed	USR-E044	2026-06-30 02:25:02.720936+00	회귀 테스트 자동화와 결함 추적 체계 구축 | 담당조직: 개발본부 / QA/DevOps팀 | 우선순위: 보통 | 매출배분: 500,000,000원 | 주요기술: QA Automation, Selenium, API Test
P-2026-012	통합 관리자 콘솔	active	USR-E033	2026-06-30 02:25:02.720936+00	운영자용 통합 관리 화면과 권한 체계 구축 | 담당조직: 개발본부 / 프론트엔드팀 | 우선순위: 보통 | 매출배분: 750,000,000원 | 주요기술: React, Design System, Admin
P-2026-013	고객사 API 게이트웨이	planned	USR-E027	2026-06-30 02:25:02.720936+00	고객사 연동 API 표준화와 트래픽 제어 | 담당조직: 개발본부 / 백엔드팀 | 우선순위: 높음 | 매출배분: 900,000,000원 | 주요기술: API Gateway, Security, MSA
P-2026-014	경영 데이터 대시보드 구축	active	USR-E005	2026-06-30 02:25:02.720936+00	경영 KPI, 프로젝트 손익, 인력 현황 통합 시각화 | 담당조직: 경영본부 / 기획팀 | 우선순위: 보통 | 매출배분: 400,000,000원 | 주요기술: BI, Dashboard, Finance
P-2026-015	파트너 영업/계약관리 시스템	active	USR-E006	2026-06-30 02:25:02.720936+00	파트너 영업 파이프라인과 계약 승인 프로세스 관리 | 담당조직: 경영본부 / 기획팀 | 우선순위: 보통 | 매출배분: 600,000,000원 | 주요기술: CRM, Contract, Workflow
\.


--
-- Data for Name: resource_allocations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_allocations (allocation_id, demand_id, project_id, resource_name, resource_type, allocation_type, assignee_user_id, quantity, starts_on, ends_on, status, conflict_reason, created_by, created_at, updated_at, resource_id) FROM stdin;
\.


--
-- Data for Name: resource_calendar_blocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_calendar_blocks (block_id, resource_id, project_id, starts_on, ends_on, block_type, reason, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: resource_demands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_demands (demand_id, project_id, source_meeting_id, source_analysis_id, source_required_resource_index, name, resource_type, quantity, needed_from, needed_to, reason, evidence, evidence_refs, ai_confidence, demand_status, conversion_policy, created_at) FROM stdin;
\.


--
-- Data for Name: resource_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_profiles (resource_id, resource_type, resource_name, capacity, unit, location, owner_user_id, status, metadata, created_by, created_at, updated_at) FROM stdin;
RES-E001	human	김도윤	1.000	person	경영본부	USR-E001	active	{"duty": "대표이사", "phone": "010-4001-7017", "login_id": "E001", "position": "대표이사", "hire_date": "2022-06-04", "team_name": "CEO실", "auth_group": "ADMIN", "company_id": "SSK-TECH", "skill_tags": ["경영전략", "리더십", "대외협력"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "파트너 영업/계약관리 시스템", "annual_salary_krw": 180000000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E001	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E002	human	박서연	1.000	person	경영본부	USR-E002	active	{"duty": "경영지원실장", "phone": "010-4002-7034", "login_id": "E002", "position": "책임", "hire_date": "2018-11-07", "team_name": "CEO실", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["운영관리", "보고체계", "리스크관리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 78740000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E002	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E003	human	이민준	1.000	person	경영본부	USR-E003	active	{"duty": "인사팀장", "phone": "010-4003-7051", "login_id": "E003", "position": "책임", "hire_date": "2025-04-10", "team_name": "인사팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["채용", "평가", "조직문화"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 89110000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E003	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E004	human	최지우	1.000	person	경영본부	USR-E004	active	{"duty": "HR담당", "phone": "010-4004-7068", "login_id": "E004", "position": "선임", "hire_date": "2021-09-13", "team_name": "인사팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["교육", "온보딩", "인사운영"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 61480000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E004	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E005	human	정하준	1.000	person	경영본부	USR-E005	active	{"duty": "기획팀장", "phone": "010-4005-7085", "login_id": "E005", "position": "책임", "hire_date": "2017-02-16", "team_name": "기획팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["사업기획", "성과관리", "PMO"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 91850000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E005	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E006	human	한소영	1.000	person	경영본부	USR-E006	active	{"duty": "사업기획담당", "phone": "010-4006-7102", "login_id": "E006", "position": "선임", "hire_date": "2024-07-19", "team_name": "기획팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["시장분석", "제안서", "요건정리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "파트너 영업/계약관리 시스템", "annual_salary_krw": 64220000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E006	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E007	human	오지훈	1.000	person	경영본부	USR-E007	active	{"duty": "기획지원", "phone": "010-4007-7119", "login_id": "E007", "position": "사원", "hire_date": "2020-12-22", "team_name": "기획팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["문서관리", "회의록", "자료조사"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "파트너 영업/계약관리 시스템", "annual_salary_krw": 38590000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E007	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E008	human	강유진	1.000	person	경영본부	USR-E008	active	{"duty": "재무팀장", "phone": "010-4008-7136", "login_id": "E008", "position": "책임", "hire_date": "2016-05-25", "team_name": "재무팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["예산관리", "손익관리", "자금계획"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 86960000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E008	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E009	human	윤태현	1.000	person	경영본부	USR-E009	active	{"duty": "회계/자금담당", "phone": "010-4009-7153", "login_id": "E009", "position": "선임", "hire_date": "2023-10-03", "team_name": "재무팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["정산", "회계", "계약검토"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "구독결제/정산 시스템", "annual_salary_krw": 59330000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E009	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E010	human	신예린	1.000	person	경영본부	USR-E010	active	{"duty": "재무지원", "phone": "010-4010-7170", "login_id": "E010", "position": "사원", "hire_date": "2019-03-06", "team_name": "재무팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["증빙관리", "세금계산서", "마감지원"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "경영본부", "work_location": "서울 본사 12F", "employment_type": "정규직", "primary_project": "경영 데이터 대시보드 구축", "annual_salary_krw": 42700000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E010	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E011	human	문태오	1.000	person	연구소	USR-E011	active	{"duty": "연구소장", "phone": "010-4011-7187", "login_id": "E011", "position": "수석", "hire_date": "2015-08-09", "team_name": "AI연구팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["AI전략", "논문검토", "기술로드맵"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "AI 고객상담 챗봇 플랫폼", "annual_salary_krw": 122070000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E011	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E012	human	서하늘	1.000	person	연구소	USR-E012	active	{"duty": "AI리드", "phone": "010-4012-7204", "login_id": "E012", "position": "책임", "hire_date": "2022-01-12", "team_name": "AI연구팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["LLM", "NLP", "모델평가"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "AI 고객상담 챗봇 플랫폼", "annual_salary_krw": 92440000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E012	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E013	human	조은서	1.000	person	연구소	USR-E013	active	{"duty": "NLP연구원", "phone": "010-4013-7221", "login_id": "E013", "position": "선임", "hire_date": "2018-06-15", "team_name": "AI연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["자연어처리", "프롬프트", "평가셋"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "AI 고객상담 챗봇 플랫폼", "annual_salary_krw": 64810000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E013	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E014	human	배준호	1.000	person	연구소	USR-E014	active	{"duty": "컴퓨터비전연구원", "phone": "010-4014-7238", "login_id": "E014", "position": "선임", "hire_date": "2025-11-18", "team_name": "AI연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["비전AI", "딥러닝", "모델튜닝"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "제조 불량 탐지 비전 AI", "annual_salary_krw": 57180000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E014	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E015	human	임가온	1.000	person	연구소	USR-E015	active	{"duty": "주니어연구원", "phone": "010-4015-7255", "login_id": "E015", "position": "사원", "hire_date": "2021-04-21", "team_name": "AI연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["데이터라벨링", "실험보조", "리포팅"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 40550000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E015	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E016	human	권도현	1.000	person	연구소	USR-E016	active	{"duty": "데이터연구팀장", "phone": "010-4016-7272", "login_id": "E016", "position": "수석", "hire_date": "2017-09-24", "team_name": "데이터연구팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["데이터전략", "분석설계", "품질관리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "데이터 레이크 분석 PoC", "annual_salary_krw": 110920000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E016	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E017	human	장유나	1.000	person	연구소	USR-E017	active	{"duty": "데이터사이언티스트", "phone": "010-4017-7289", "login_id": "E017", "position": "책임", "hire_date": "2024-02-02", "team_name": "데이터연구팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["추천모델", "통계분석", "AB테스트"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "개인화 추천엔진 고도화", "annual_salary_krw": 81290000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E017	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E018	human	백시우	1.000	person	연구소	USR-E018	active	{"duty": "ML엔지니어", "phone": "010-4018-7306", "login_id": "E018", "position": "선임", "hire_date": "2020-07-05", "team_name": "데이터연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["피처엔지니어링", "MLOps", "모델서빙"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "데이터 레이크 분석 PoC", "annual_salary_krw": 62660000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E018	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E019	human	남지민	1.000	person	연구소	USR-E019	active	{"duty": "데이터분석가", "phone": "010-4019-7323", "login_id": "E019", "position": "선임", "hire_date": "2016-12-08", "team_name": "데이터연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["BI", "SQL", "시각화"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "데이터 레이크 분석 PoC", "annual_salary_krw": 64030000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E019	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E020	human	유하린	1.000	person	연구소	USR-E020	active	{"duty": "데이터어시스턴트", "phone": "010-4020-7340", "login_id": "E020", "position": "사원", "hire_date": "2023-05-11", "team_name": "데이터연구팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["데이터정제", "리포트", "대시보드"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "데이터 레이크 분석 PoC", "annual_salary_krw": 38400000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E020	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E021	human	홍서준	1.000	person	연구소	USR-E021	active	{"duty": "R&D팀장", "phone": "010-4021-7357", "login_id": "E021", "position": "수석", "hire_date": "2019-10-14", "team_name": "플랫폼R&D팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["플랫폼아키텍처", "MLOps", "클라우드"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 108770000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E021	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E022	human	고아라	1.000	person	연구소	USR-E022	active	{"duty": "시스템아키텍트", "phone": "010-4022-7374", "login_id": "E022", "position": "책임", "hire_date": "2015-03-17", "team_name": "플랫폼R&D팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["분산시스템", "API설계", "보안"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 79140000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E022	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E023	human	안준서	1.000	person	연구소	USR-E023	active	{"duty": "플랫폼연구원", "phone": "010-4023-7391", "login_id": "E023", "position": "선임", "hire_date": "2022-08-20", "team_name": "플랫폼R&D팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["서비스설계", "성능개선", "인프라"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 60510000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E023	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E024	human	송다은	1.000	person	연구소	USR-E024	active	{"duty": "MLOps연구원", "phone": "010-4024-7408", "login_id": "E024", "position": "선임", "hire_date": "2018-01-23", "team_name": "플랫폼R&D팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["배포자동화", "모니터링", "파이프라인"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 61880000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E024	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E025	human	차민재	1.000	person	연구소	USR-E025	active	{"duty": "연구지원", "phone": "010-4025-7425", "login_id": "E025", "position": "사원", "hire_date": "2025-06-01", "team_name": "플랫폼R&D팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["문서화", "실험관리", "개발지원"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "연구소", "work_location": "서울 R&D센터 8F", "employment_type": "정규직", "primary_project": "LLM 업무자동화 연구", "annual_salary_krw": 45250000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E025	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E026	human	유민석	1.000	person	개발본부	USR-E026	active	{"duty": "개발본부장", "phone": "010-4026-7442", "login_id": "E026", "position": "수석", "hire_date": "2021-11-04", "team_name": "백엔드팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["개발전략", "아키텍처", "기술관리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "SaaS ERP 백엔드 리뉴얼", "annual_salary_krw": 124620000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E026	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E027	human	강민아	1.000	person	개발본부	USR-E027	active	{"duty": "백엔드팀장", "phone": "010-4027-7459", "login_id": "E027", "position": "책임", "hire_date": "2017-04-07", "team_name": "백엔드팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["Java", "Spring", "API설계"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "SaaS ERP 백엔드 리뉴얼", "annual_salary_krw": 85990000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E027	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E028	human	이준혁	1.000	person	개발본부	USR-E028	active	{"duty": "백엔드개발자", "phone": "010-4028-7476", "login_id": "E028", "position": "선임", "hire_date": "2024-09-10", "team_name": "백엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Java", "Spring", "마이크로서비스"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "SaaS ERP 백엔드 리뉴얼", "annual_salary_krw": 58360000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E028	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E029	human	박하윤	1.000	person	개발본부	USR-E029	active	{"duty": "백엔드개발자", "phone": "010-4029-7493", "login_id": "E029", "position": "선임", "hire_date": "2020-02-13", "team_name": "백엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Node.js", "API", "배치"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "SaaS ERP 백엔드 리뉴얼", "annual_salary_krw": 59730000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E029	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E030	human	김서준	1.000	person	개발본부	USR-E030	active	{"duty": "주니어개발자", "phone": "010-4030-7510", "login_id": "E030", "position": "사원", "hire_date": "2016-07-16", "team_name": "백엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["API개발", "테스트", "문서화"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "SaaS ERP 백엔드 리뉴얼", "annual_salary_krw": 43100000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E030	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E031	human	최서아	1.000	person	개발본부	USR-E031	active	{"duty": "API개발자", "phone": "010-4031-7527", "login_id": "E031", "position": "사원", "hire_date": "2023-12-19", "team_name": "백엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["REST API", "문서화", "연동테스트"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "고객사 API 게이트웨이", "annual_salary_krw": 44470000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E031	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E032	human	정윤재	1.000	person	개발본부	USR-E032	active	{"duty": "데이터베이스리드", "phone": "010-4032-7544", "login_id": "E032", "position": "책임", "hire_date": "2019-05-22", "team_name": "백엔드팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["DB설계", "성능튜닝", "데이터모델링"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "구독결제/정산 시스템", "annual_salary_krw": 92840000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E032	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E033	human	오세은	1.000	person	개발본부	USR-E033	active	{"duty": "프론트엔드팀장", "phone": "010-4033-7561", "login_id": "E033", "position": "책임", "hire_date": "2015-10-25", "team_name": "프론트엔드팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["React", "UX", "웹아키텍처"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "통합 관리자 콘솔", "annual_salary_krw": 85210000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E033	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E034	human	신지호	1.000	person	개발본부	USR-E034	active	{"duty": "프론트엔드개발자", "phone": "010-4034-7578", "login_id": "E034", "position": "선임", "hire_date": "2022-03-03", "team_name": "프론트엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["React", "TypeScript", "상태관리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "공공기관 민원 포털 고도화", "annual_salary_krw": 57580000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E034	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E035	human	장서윤	1.000	person	개발본부	USR-E035	active	{"duty": "UI개발자", "phone": "010-4035-7595", "login_id": "E035", "position": "선임", "hire_date": "2018-08-06", "team_name": "프론트엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["UI컴포넌트", "웹접근성", "CSS"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "통합 관리자 콘솔", "annual_salary_krw": 58950000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E035	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E036	human	임도현	1.000	person	개발본부	USR-E036	active	{"duty": "웹개발자", "phone": "010-4036-7612", "login_id": "E036", "position": "사원", "hire_date": "2025-01-09", "team_name": "프론트엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["React", "퍼블리싱", "테스트"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "통합 관리자 콘솔", "annual_salary_krw": 42320000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E036	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E037	human	배수빈	1.000	person	개발본부	USR-E037	active	{"duty": "퍼블리셔", "phone": "010-4037-7629", "login_id": "E037", "position": "사원", "hire_date": "2021-06-12", "team_name": "프론트엔드팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["HTML", "CSS", "디자인시스템"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "공공기관 민원 포털 고도화", "annual_salary_krw": 43690000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E037	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E038	human	한유찬	1.000	person	개발본부	USR-E038	active	{"duty": "UX엔지니어", "phone": "010-4038-7646", "login_id": "E038", "position": "책임", "hire_date": "2017-11-15", "team_name": "프론트엔드팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["사용자흐름", "프로토타입", "프론트설계"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "공공기관 민원 포털 고도화", "annual_salary_krw": 83060000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E038	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E039	human	윤서진	1.000	person	개발본부	USR-E039	active	{"duty": "모바일팀장", "phone": "010-4039-7663", "login_id": "E039", "position": "책임", "hire_date": "2024-04-18", "team_name": "모바일팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["iOS", "Android", "앱아키텍처"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "모바일 현장관리 앱", "annual_salary_krw": 93430000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E039	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E040	human	남도윤	1.000	person	개발본부	USR-E040	active	{"duty": "iOS개발자", "phone": "010-4040-7680", "login_id": "E040", "position": "선임", "hire_date": "2020-09-21", "team_name": "모바일팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Swift", "iOS", "앱배포"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "모바일 현장관리 앱", "annual_salary_krw": 56800000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E040	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E041	human	권예나	1.000	person	개발본부	USR-E041	active	{"duty": "Android개발자", "phone": "010-4041-7697", "login_id": "E041", "position": "선임", "hire_date": "2016-02-24", "team_name": "모바일팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Kotlin", "Android", "앱성능"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "모바일 현장관리 앱", "annual_salary_krw": 58170000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E041	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E042	human	조하람	1.000	person	개발본부	USR-E042	active	{"duty": "Flutter개발자", "phone": "010-4042-7714", "login_id": "E042", "position": "사원", "hire_date": "2023-07-02", "team_name": "모바일팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Flutter", "Dart", "앱UI"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "모바일 현장관리 앱", "annual_salary_krw": 41540000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E042	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E043	human	백현우	1.000	person	개발본부	USR-E043	active	{"duty": "모바일QA", "phone": "010-4043-7731", "login_id": "E043", "position": "사원", "hire_date": "2019-12-05", "team_name": "모바일팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["모바일테스트", "이슈관리", "릴리즈검증"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "모바일 현장관리 앱", "annual_salary_krw": 42910000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E043	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E044	human	홍지아	1.000	person	개발본부	USR-E044	active	{"duty": "QA/DevOps팀장", "phone": "010-4044-7748", "login_id": "E044", "position": "책임", "hire_date": "2015-05-08", "team_name": "QA/DevOps팀", "auth_group": "MANAGER", "company_id": "SSK-TECH", "skill_tags": ["테스트전략", "CI/CD", "품질관리"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "DevOps 클라우드 전환", "annual_salary_krw": 91280000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E044	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E045	human	서지완	1.000	person	개발본부	USR-E045	active	{"duty": "DevOps엔지니어", "phone": "010-4045-7765", "login_id": "E045", "position": "선임", "hire_date": "2022-10-11", "team_name": "QA/DevOps팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Kubernetes", "CI/CD", "클라우드"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "DevOps 클라우드 전환", "annual_salary_krw": 63650000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E045	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E046	human	문서현	1.000	person	개발본부	USR-E046	active	{"duty": "QA엔지니어", "phone": "010-4046-7782", "login_id": "E046", "position": "선임", "hire_date": "2018-03-14", "team_name": "QA/DevOps팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["테스트케이스", "자동화", "결함분석"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "품질자동화 테스트 플랫폼", "annual_salary_krw": 56020000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E046	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E047	human	안태민	1.000	person	개발본부	USR-E047	active	{"duty": "테스트자동화담당", "phone": "010-4047-7799", "login_id": "E047", "position": "사원", "hire_date": "2025-08-17", "team_name": "QA/DevOps팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["Selenium", "API테스트", "스크립트"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "품질자동화 테스트 플랫폼", "annual_salary_krw": 39390000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E047	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E048	human	고지윤	1.000	person	개발본부	USR-E048	active	{"duty": "클라우드운영담당", "phone": "010-4048-7816", "login_id": "E048", "position": "사원", "hire_date": "2021-01-20", "team_name": "QA/DevOps팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["운영모니터링", "배포지원", "장애대응"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "DevOps 클라우드 전환", "annual_salary_krw": 40760000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E048	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E049	human	차유건	1.000	person	개발본부	USR-E049	active	{"duty": "보안/인프라리드", "phone": "010-4049-7833", "login_id": "E049", "position": "책임", "hire_date": "2017-06-23", "team_name": "QA/DevOps팀", "auth_group": "LEAD", "company_id": "SSK-TECH", "skill_tags": ["보안점검", "인프라설계", "감사대응"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "DevOps 클라우드 전환", "annual_salary_krw": 89130000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E049	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
RES-E050	human	송예준	1.000	person	개발본부	USR-E050	active	{"duty": "SRE", "phone": "010-4050-7850", "login_id": "E050", "position": "선임", "hire_date": "2024-11-01", "team_name": "QA/DevOps팀", "auth_group": "MEMBER", "company_id": "SSK-TECH", "skill_tags": ["SRE", "관측성", "성능개선"], "source_file": "saessak_virtual_company_dataset_pms_login_revised.xlsx", "status_text": "재직", "account_note": "샘플용 통일 비밀번호. 실제 운영에서는 해시 저장/최초 변경 필요", "company_name": "새싹테크솔루션 주식회사", "english_name": "Saessak Tech Solutions Co., Ltd.", "login_method": "사번 로그인", "division_name": "개발본부", "work_location": "서울 개발센터 10F", "employment_type": "정규직", "primary_project": "DevOps 클라우드 전환", "annual_salary_krw": 61500000, "annual_revenue_krw": 10000000000, "account_status_text": "활성", "total_allocation_rate": 1.0}	USR-E050	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
\.


--
-- Data for Name: resource_usage_entries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.resource_usage_entries (usage_id, allocation_id, project_id, resource_id, resource_name, resource_type, usage_date, quantity, unit, cost_amount, usage_status, note, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: risks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.risks (risk_id, project_id, source_meeting_id, source_analysis_id, title, level, evidence, evidence_refs, ai_confidence, status, created_at) FROM stdin;
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schedules (schedule_id, project_id, title, start_date, end_date, milestone, status, created_at) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (service, version, name, checksum_sha256, applied_at) FROM stdin;
platform	0001_platform_initial	0001_platform_initial.sql	fd9c23196733d00a4aab03a7c627b800824f45a967dac228a6798c9a3890af89	2026-06-30 01:19:14.35081+00
platform	0002_password_reset_tokens	0002_password_reset_tokens.sql	49a63f75a50a3e6d214c0b4afb7b8adaa98ea3267774c32a6143f5cbeb2d3af5	2026-06-30 01:19:14.35081+00
platform	0003_email_distributions	0003_email_distributions.sql	3b4cf7d78bf3078a1ff392bbee02b9fed94f8970b919cfaa61a3a1eec3c374b4	2026-06-30 01:19:14.35081+00
platform	0004_email_delivery_retry	0004_email_delivery_retry.sql	ed68efdd5da7552f3e09f0b4fa3fd3ebad09261e23db8c8d599ca323c1c1306d	2026-06-30 01:19:14.35081+00
platform	0005_resource_allocation	0005_resource_allocation.sql	6d7763570a133d5475a31a9c096b67f16811b09332f0eeb8b8daaea9bc328e2c	2026-06-30 01:19:14.35081+00
platform	0006_resource_profiles	0006_resource_profiles.sql	834ae6b086a2d9f4ee8f2d3f340508041788381794e699e8318ad7e2997105bc	2026-06-30 01:19:14.35081+00
platform	0007_resource_usage_cost	0007_resource_usage_cost.sql	a397cc697025b55b82394bf91b861ab7214acfbad3e073dffb6774260b7af5f1	2026-06-30 01:19:14.35081+00
platform	0008_cost_candidate_review	0008_cost_candidate_review.sql	610ffb61a17d8191d52e7e19ba37ed1d0867238c00a99aadf0bbaf52a7295c58	2026-06-30 01:19:14.35081+00
platform	0009_resource_calendar_blocks	0009_resource_calendar_blocks.sql	582143a0e03d214a754bf8d7f5f54c38af05eec88421512fc1a6a0a6e63ff143	2026-06-30 01:19:14.35081+00
platform	0010_project_cost_handoff	0010_project_cost_handoff.sql	6ac80bbeea4a93feba023b6c67a475f42a8b821ce33747d662b1b8259f8b66c5	2026-06-30 01:19:14.35081+00
platform	0011_project_cost_handoff_reconciliation	0011_project_cost_handoff_reconciliation.sql	747364509457f0ed9a5b743b2ab7ee8846d68fdfd620c96ff35ba1d4e5086451	2026-06-30 01:19:14.35081+00
platform	0012_project_cost_handoff_delivery	0012_project_cost_handoff_delivery.sql	4efc3fcdb5cdfc04aa9c2ce59415f37c25170041a1af6cd93ad8916a9be38d14	2026-06-30 01:19:14.35081+00
platform	0013_project_knowledge_items	0013_project_knowledge_items.sql	ea993815fc7b8b87b3c62de5db26b6d674d9cb7cd98b7c4eef07ed14d0775164	2026-06-30 01:19:14.35081+00
platform	0014_project_member_staffing	0014_project_member_staffing.sql	7df66ac256147dc3ebc7b7f01ffbfe89ce53c80fa9f6242e5eb33fe942bc736a	2026-06-30 01:19:14.35081+00
platform	0015_project_description	0015_project_description.sql	5ecc7cda0916526fecc8b3c22eb7c743813c3072710e5880a16fea4280b2cdf3	2026-06-30 01:19:14.35081+00
collection	0001_collection_initial	0001_collection_initial.sql	d822c8dbaa826dee49db6659c5be19c510b54df9980b117d19213dc3384e27f8	2026-06-30 01:19:17.61795+00
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tasks (task_id, project_id, source_meeting_id, source_analysis_id, source_action_item_index, title, description, assignee, due_date, priority, ai_confidence, evidence_refs, conversion_policy, conversion_status, status, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (user_id, employee_no, name, email, role, password_hash, status, created_at, updated_at) FROM stdin;
USR-cd3cdd218c17	AUTH101950	Auth Smoke	auth101950@local.test	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	password_change_required	2026-06-30 01:19:50.974723+00	2026-06-30 01:19:50.974723+00
USR-a346f5d41279	GUARD101950	Guard Smoke	guard101950@local.test	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 01:19:50.970115+00	2026-06-30 01:19:51.200304+00
USR-E001	E001	김도윤	e001@saessak-tech.example	admin	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E002	E002	박서연	e002@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E003	E003	이민준	e003@saessak-tech.example	resource_manager	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E004	E004	최지우	e004@saessak-tech.example	resource_manager	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E005	E005	정하준	e005@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E006	E006	한소영	e006@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E007	E007	오지훈	e007@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E008	E008	강유진	e008@saessak-tech.example	finance	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E009	E009	윤태현	e009@saessak-tech.example	finance	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E010	E010	신예린	e010@saessak-tech.example	finance	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E011	E011	문태오	e011@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E012	E012	서하늘	e012@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E013	E013	조은서	e013@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E014	E014	배준호	e014@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E015	E015	임가온	e015@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E016	E016	권도현	e016@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E017	E017	장유나	e017@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E018	E018	백시우	e018@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E019	E019	남지민	e019@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E020	E020	유하린	e020@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E021	E021	홍서준	e021@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E022	E022	고아라	e022@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E023	E023	안준서	e023@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E024	E024	송다은	e024@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E025	E025	차민재	e025@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E026	E026	유민석	e026@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E027	E027	강민아	e027@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E028	E028	이준혁	e028@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E029	E029	박하윤	e029@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E030	E030	김서준	e030@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E031	E031	최서아	e031@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E032	E032	정윤재	e032@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E033	E033	오세은	e033@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E034	E034	신지호	e034@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E035	E035	장서윤	e035@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E036	E036	임도현	e036@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E037	E037	배수빈	e037@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E038	E038	한유찬	e038@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E039	E039	윤서진	e039@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E040	E040	남도윤	e040@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E041	E041	권예나	e041@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E042	E042	조하람	e042@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E043	E043	백현우	e043@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E044	E044	홍지아	e044@saessak-tech.example	pm	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E045	E045	서지완	e045@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E046	E046	문서현	e046@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E047	E047	안태민	e047@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E048	E048	고지윤	e048@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E049	E049	차유건	e049@saessak-tech.example	pl	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
USR-E050	E050	송예준	e050@saessak-tech.example	member	pbkdf2_sha256$ai_pms_collab_demo_20260630$014155de32956c18e32cd7dd8ebc5ca9c9baa286481387520444d5a0e41ba127	active	2026-06-30 02:25:02.720936+00	2026-06-30 04:43:50.467821+00
\.


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 9, true);


--
-- Name: collection_job_event_logs_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.collection_job_event_logs_event_id_seq', 30, true);


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

\unrestrict LcMaWRK1juSRmFcraUZ1LG8wbCQN2uIR2UIQalD3dTHWIwjAqJhkW8a2jk3IawO

