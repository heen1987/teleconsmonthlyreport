// ─────────────────────────────────────────────
// AI-PMS Web Client — 공통 타입 정의
// 이 파일을 수정하면 main.tsx 및 모든 컴포넌트에 반영됩니다.
// ─────────────────────────────────────────────

export type UserRole =
  | "admin"
  | "pm"
  | "pl"
  | "member"
  | "finance"
  | "resource_manager"
  | "viewer";

export type UserStatus =
  | "password_change_required"
  | "active"
  | "locked"
  | "disabled";

export type User = {
  user_id: string;
  employee_no: string;
  name: string;
  email?: string | null;
  role: string;
  status: string;
};

export type UserCreateForm = {
  employee_no: string;
  name: string;
  email: string;
  role: UserRole;
  initial_password: string;
};

export type UserEditForm = {
  name: string;
  email: string;
  role: UserRole;
  status: UserStatus;
};

export type AuthView = "login" | "reset-request" | "reset-confirm";

export type PasswordResetRequestForm = { employee_no: string; email: string };
export type PasswordResetConfirmForm = {
  token: string;
  new_password: string;
  confirm_password: string;
};

export type LoginResponse = {
  access_token: string;
  token_type: "bearer";
  expires_at: string;
  user: User;
  password_change_required: boolean;
};

export type PasswordResetRequestResponse = {
  employee_no: string;
  email: string;
  expires_at: string;
  delivery_status: "dev_token_returned" | "email_queued";
  reset_token?: string | null;
};

export type PasswordResetConfirmResponse = {
  employee_no: string;
  status: string;
  revoked_tokens: number;
};

export type AuthSession = {
  accessToken: string;
  expiresAt: string;
  user: User;
};

export type AppView = "visual" | "review" | "admin";

export const KNOWLEDGE_ITEM_KINDS = [
  "all",
  "summary",
  "decision",
  "action_item",
  "risk",
  "required_resource",
] as const;

export type KnowledgeItemKind = (typeof KNOWLEDGE_ITEM_KINDS)[number];

export type Project = {
  project_id: string;
  name: string;
  description?: string | null;
  pm_user_id?: string | null;
  status: string;
};

export type ProjectMember = {
  project_id: string;
  user_id: string;
  employee_no: string;
  name: string;
  email?: string | null;
  user_role?: string | null;
  project_role: string;
  allocation_percent: number;
  planned_mm: number;
  staffing_note?: string | null;
  annual_salary_krw?: number | null;
  allocated_cost_krw?: number | null;
};

export type ProjectDashboard = {
  project_id: string;
  tasks_total: number;
  tasks_draft: number;
  tasks_overdue: number;
  meetings_total: number;
  pending_reviews: number;
  resource_demands_candidate: number;
  risks_candidate: number;
  risks_unresolved: number;
  resource_conflicts: number;
  distribution_failures: number;
  knowledge_items: number;
};

export type ProjectDetail = Project & {
  members: ProjectMember[];
  dashboard: ProjectDashboard;
};

export type MeetingStatusItem = {
  meeting_id: string;
  project_id: string;
  project_name: string;
  title: string;
  status: string;
  created_by?: string | null;
  created_at: string;
  latest_analysis_id?: string | null;
  latest_analysis_status?: string | null;
  latest_model_name?: string | null;
};

export type Dashboard = {
  projects: number;
  meetings: number;
  pending_reviews: number;
  draft_tasks: number;
  overdue_tasks: number;
  resource_demands: number;
  resource_usage_entries: number;
  cost_candidates: number;
  candidate_risks: number;
  unresolved_risks: number;
  resource_conflicts: number;
  distribution_failures: number;
  knowledge_items: number;
};

export type OperationQueueSection = {
  status_counts: Record<string, number>;
  retry_due: number;
  attention_count: number;
  latest_created_at?: string | null;
  next_retry_at?: string | null;
  last_error?: string | null;
};

export type OperationQueueStatus = {
  generated_at: string;
  email_distributions: OperationQueueSection;
  erp_handoffs: OperationQueueSection;
};

export type DelayedTaskRiskPromotion = {
  scanned_overdue_tasks: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};

export type CostCandidateRiskPromotion = {
  scanned_cost_candidates: number;
  threshold_amount: number;
  currency: string;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};

export type ResourceConflictRiskPromotion = {
  scanned_conflicts: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};

export type UnassignedResourceDemandRiskPromotion = {
  scanned_demands: number;
  due_within_days: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};

export type ResourceUsageOverrunRiskPromotion = {
  scanned_usage_entries: number;
  threshold_ratio: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};

export type ProjectKnowledgeItem = {
  knowledge_id: string;
  project_id: string;
  source_meeting_id?: string | null;
  source_analysis_id?: string | null;
  item_kind: Exclude<KnowledgeItemKind, "all"> | string;
  source_item_index: number;
  title: string;
  content: string;
  evidence_refs: EvidenceRef[];
  tags: string[];
  status: string;
  created_at: string;
};

export type EvidenceRef = {
  segment_id?: string | null;
  speaker?: string | null;
  start_ms?: number | null;
  end_ms?: number | null;
  quote?: string | null;
};

export type TranscriptSegment = {
  segment_id: string;
  speaker?: string | null;
  text: string;
  start_ms?: number | null;
  end_ms?: number | null;
};

export type DecisionCandidate = {
  content: string;
  evidence?: string | null;
  evidence_refs?: EvidenceRef[];
  confidence: number;
};

export type ActionItemCandidate = {
  title: string;
  assignee?: string | null;
  due_date?: string | null;
  target_module: string;
  evidence?: string | null;
  evidence_refs?: EvidenceRef[];
  priority: "low" | "medium" | "high";
  confidence: number;
  task_conversion_policy: "manual_review_required";
  task_conversion_status: "candidate" | "converted" | "rejected";
  task_conversion_reason?: string | null;
};

export type RiskCandidate = {
  title: string;
  level: "low" | "medium" | "high";
  evidence?: string | null;
  evidence_refs?: EvidenceRef[];
  confidence: number;
};

export type RequiredResourceCandidate = {
  name: string;
  resource_type: "human" | "equipment" | "room" | "vehicle" | "software" | "other";
  quantity?: number | null;
  needed_from?: string | null;
  needed_to?: string | null;
  reason?: string | null;
  evidence?: string | null;
  evidence_refs?: EvidenceRef[];
  confidence: number;
};

export type MeetingAnalysisResult = {
  schema_version: string;
  language: string;
  summary: string;
  transcript_segments: TranscriptSegment[];
  decisions: DecisionCandidate[];
  action_items: ActionItemCandidate[];
  risks: RiskCandidate[];
  required_resources: RequiredResourceCandidate[];
  requires_human_approval: boolean;
};

export type ReviewPackage = {
  meeting: { meeting_id: string; project_id: string; title: string; status: string };
  analysis_id: string;
  analysis_status: string;
  model_name: string;
  result: MeetingAnalysisResult;
  counts: Record<string, number>;
  capabilities: { can_edit: boolean; can_approve: boolean; can_reject: boolean; can_distribute: boolean };
  warnings: string[];
};

export type EmailRecipient = { email: string; name?: string | null; role?: string | null };

export type EmailDistributionPreview = {
  screen_id: "W-006";
  meeting: ReviewPackage["meeting"];
  analysis_id: string;
  subject: string;
  body: string;
  recipients: EmailRecipient[];
  can_distribute: boolean;
  delivery_mode: "dev_log" | "smtp";
};

export type EmailDeliveryAttempt = {
  attempt_id: string;
  recipient_email: string;
  recipient_name?: string | null;
  status: string;
  provider_message_id?: string | null;
  error_message?: string | null;
  attempted_at: string;
};

export type EmailDistribution = {
  distribution_id: string;
  meeting_id: string;
  analysis_id: string;
  subject: string;
  body: string;
  recipients: EmailRecipient[];
  status: string;
  delivery_mode: string;
  requested_by?: string | null;
  created_at: string;
  sent_at?: string | null;
  attempts: EmailDeliveryAttempt[];
};

export type ResourceProfile = {
  resource_id: string;
  resource_name: string;
  resource_type: string;
  capacity: number;
  unit: string;
  location?: string | null;
  owner_user_id?: string | null;
  status: string;
  created_by?: string | null;
};

export type ResourceAvailability = ResourceProfile & {
  is_available: boolean;
  blocking_allocation_id?: string | null;
  blocking_calendar_block_id?: string | null;
};

export type ResourceUsage = {
  usage_id: string;
  allocation_id: string;
  project_id: string;
  resource_id?: string | null;
  resource_name: string;
  resource_type: string;
  usage_date: string;
  quantity: number;
  unit: string;
  cost_amount?: number | null;
  usage_status: string;
  note?: string | null;
  created_by?: string | null;
};

export type ProjectCostCandidate = {
  cost_id: string;
  project_id: string;
  source_type: string;
  source_id: string;
  cost_type: string;
  amount: number;
  currency: string;
  status: string;
  description?: string | null;
  created_by?: string | null;
  reviewed_by?: string | null;
  reviewed_at?: string | null;
  review_note?: string | null;
};

export type ProjectCostHandoff = {
  handoff_id: string;
  cost_id: string;
  project_id: string;
  target_system: string;
  status: string;
  attempt_count: number;
};

export type ApkMetadata = {
  app_name: string;
  package_name: string;
  apk: string;
  apk_alias?: string;
  sha256: string;
  size_bytes: number;
  size_mb: string;
  published_at: string;
  layout: string;
  signing: string;
};

export type PublicExecutionCommand = { name: string; label: string; commands: string[] };

export type PublicExecutionUrls = {
  run_hub?: string;
  web_console?: string;
  apk_download_page?: string;
  apk_file?: string;
  apk_install_guide?: string;
  handoff_page?: string;
  review_package_json?: string;
  platform_health?: string;
  platform_docs?: string;
  collection_health?: string;
  collection_docs?: string;
  analysis_health?: string;
  analysis_docs?: string;
};

export type PublicExecutionApk = {
  app_name: string;
  package_name: string;
  file_name: string;
  alias_file_name?: string;
  sha256: string;
  size_bytes: number;
  size_mb: string;
  published_at: string;
  layout: string;
  signing: string;
};

export type PublicExecutionManifest = {
  kind: "public_execution_hub";
  public_urls: PublicExecutionUrls;
  local_urls: Record<string, string>;
  android_apk: PublicExecutionApk;
  execution_commands: PublicExecutionCommand[];
  minimum_checks: string[];
};
