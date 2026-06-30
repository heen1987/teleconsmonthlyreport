import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { Activity, AlertTriangle, Ban, BarChart3, Bell, BookOpen, CalendarDays, Check, ChevronDown, ChevronRight, CircleHelp, ClipboardList, Clock, Cpu, Database, Download, FileCheck2, FileText, Filter, Folder, Home, KeyRound, Layers, LayoutDashboard, Lock, LogOut, Mail, Menu, Mic, MoreVertical, Network, PanelLeftClose, PauseCircle, Plus, RefreshCw, RotateCcw, Save, Search, Send, Settings, ShieldCheck, Sparkles, Square, SquareKanban, UploadCloud, UserPlus, UserRound, Users } from "lucide-react";
import { AppRouter } from "./AppRouter";
import { api } from "./api/client";
import "./styles.css";

const APK_DOWNLOAD_PATH = "/downloads/";
const HANDOFF_PATH = "/handoff/";
const RUN_PATH = "/run/";
const APK_FILE_NAME = "AiPmsAndroidClient-responsive-public-debug.apk";
const APK_SHA256 = "metadata-provided-at-runtime";
const APK_PUBLISHED_AT = "metadata-provided-at-runtime";
const PUBLIC_WEB_URL = "https://textiles-zen-syndrome-ultimately.trycloudflare.com";
const PUBLIC_PLATFORM_URL = "https://other-musicians-recorded-different.trycloudflare.com";
const PUBLIC_COLLECTION_URL = "https://warrior-copyright-opinion-saturn.trycloudflare.com";
const PUBLIC_ANALYSIS_URL = "https://monday-cables-optional-cancer.trycloudflare.com";
const AUTH_STORAGE_KEY = "ai-pms-auth";
const PRODUCT_BRAND_NAME = "MEETFLOW";
const DEMO_COMPANY_NAME = "새싹SW";
const DEMO_COMPANY_REVENUE_LABEL = "50억";
const DEMO_COMPANY_HEADCOUNT = 50;
const DEMO_COMPANY_DEVELOPER_COUNT = 45;
const DEMO_COMPANY_PROJECT_COUNT = 15;
const DEMO_COMPANY_DIVISION_COUNT = 4;
const DEMO_COMPANY_DIVISIONS = ["경영본부", "AI연구소", "플랫폼개발본부", "서비스개발본부"];
const SCREEN_DESIGN_TRACE_MARKERS = [
  "WEB-01 워크스페이스",
  "WEB-02 업무보드",
  "WEB-03 문서공간",
  "WEB-04 검토·승인",
  "ADMIN-01 운영관리",
  "50명 SW개발회사",
];
const USER_ROLES: UserRole[] = ["admin", "pm", "pl", "member", "finance", "resource_manager", "viewer"];
const USER_STATUSES: UserStatus[] = ["password_change_required", "active", "locked", "disabled"];
const KNOWLEDGE_ITEM_KINDS = ["all", "summary", "decision", "action_item", "risk", "required_resource"] as const;

type UserRole = "admin" | "pm" | "pl" | "member" | "finance" | "resource_manager" | "viewer";
type UserStatus = "password_change_required" | "active" | "locked" | "disabled";
type User = { user_id: string; employee_no: string; name: string; email?: string | null; role: string; status: string };
type UserCreateForm = { employee_no: string; name: string; email: string; role: UserRole; initial_password: string };
type UserEditForm = { name: string; email: string; role: UserRole; status: UserStatus };
type AuthView = "login" | "reset-request" | "reset-confirm";
type PasswordResetRequestForm = { employee_no: string; email: string };
type PasswordResetConfirmForm = { token: string; new_password: string; confirm_password: string };
type LoginResponse = {
  access_token: string;
  token_type: "bearer";
  expires_at: string;
  user: User;
  password_change_required: boolean;
};
type PasswordResetRequestResponse = {
  employee_no: string;
  email: string;
  expires_at: string;
  delivery_status: "dev_token_returned" | "email_queued";
  reset_token?: string | null;
};
type PasswordResetConfirmResponse = { employee_no: string; status: string; revoked_tokens: number };
type AuthSession = { accessToken: string; expiresAt: string; user: User };
type AppView = "visual" | "review" | "admin";
type KnowledgeItemKind = typeof KNOWLEDGE_ITEM_KINDS[number];
type Project = { project_id: string; name: string; description?: string | null; pm_user_id?: string | null; status: string };
type ProjectMember = {
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
type ProjectDashboard = {
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
type ProjectDetail = Project & {
  members: ProjectMember[];
  dashboard: ProjectDashboard;
};
type MeetingStatusItem = {
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
type Dashboard = {
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
type OperationQueueSection = {
  status_counts: Record<string, number>;
  retry_due: number;
  attention_count: number;
  latest_created_at?: string | null;
  next_retry_at?: string | null;
  last_error?: string | null;
};
type OperationQueueStatus = {
  generated_at: string;
  email_distributions: OperationQueueSection;
  erp_handoffs: OperationQueueSection;
};
type DelayedTaskRiskPromotion = {
  scanned_overdue_tasks: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};
type CostCandidateRiskPromotion = {
  scanned_cost_candidates: number;
  threshold_amount: number;
  currency: string;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};
type ResourceConflictRiskPromotion = {
  scanned_conflicts: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};
type UnassignedResourceDemandRiskPromotion = {
  scanned_demands: number;
  due_within_days: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};
type ResourceUsageOverrunRiskPromotion = {
  scanned_usage_entries: number;
  threshold_ratio: number;
  created_risks: Array<{ risk_id: string; title: string; level: string; status: string }>;
};
type ProjectKnowledgeItem = {
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
type EvidenceRef = { segment_id?: string | null; speaker?: string | null; start_ms?: number | null; end_ms?: number | null; quote?: string | null };
type TranscriptSegment = { segment_id: string; speaker?: string | null; text: string; start_ms?: number | null; end_ms?: number | null };
type DecisionCandidate = { content: string; evidence?: string | null; evidence_refs?: EvidenceRef[]; confidence: number };
type ActionItemCandidate = {
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
type RiskCandidate = { title: string; level: "low" | "medium" | "high"; evidence?: string | null; evidence_refs?: EvidenceRef[]; confidence: number };
type RequiredResourceCandidate = {
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
type MeetingAnalysisResult = {
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
type ReviewPackage = {
  meeting: { meeting_id: string; project_id: string; title: string; status: string };
  analysis_id: string;
  analysis_status: string;
  model_name: string;
  result: MeetingAnalysisResult;
  counts: Record<string, number>;
  capabilities: { can_edit: boolean; can_approve: boolean; can_reject: boolean; can_distribute: boolean };
  warnings: string[];
};
type EmailRecipient = { email: string; name?: string | null; role?: string | null };
type EmailDistributionPreview = {
  screen_id: "W-006";
  meeting: ReviewPackage["meeting"];
  analysis_id: string;
  subject: string;
  body: string;
  recipients: EmailRecipient[];
  can_distribute: boolean;
  delivery_mode: "dev_log" | "smtp";
};
type EmailDeliveryAttempt = {
  attempt_id: string;
  recipient_email: string;
  recipient_name?: string | null;
  status: string;
  provider_message_id?: string | null;
  error_message?: string | null;
  attempted_at: string;
};
type EmailDistribution = {
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
type ResourceProfile = {
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
type ResourceAvailability = ResourceProfile & {
  is_available: boolean;
  blocking_allocation_id?: string | null;
  blocking_calendar_block_id?: string | null;
};
type ResourceUsage = {
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
type ProjectCostCandidate = {
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
type ProjectCostHandoff = {
  handoff_id: string;
  cost_id: string;
  project_id: string;
  target_system: string;
  status: string;
  attempt_count: number;
};
type ApkMetadata = {
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
type PublicExecutionCommand = { name: string; label: string; commands: string[] };
type PublicExecutionUrls = {
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
type PublicExecutionApk = {
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
type PublicExecutionManifest = {
  kind: "public_execution_hub";
  public_urls: PublicExecutionUrls;
  local_urls: Record<string, string>;
  android_apk: PublicExecutionApk;
  execution_commands: PublicExecutionCommand[];
  minimum_checks: string[];
};

function readStoredAuth(): AuthSession | null {
  const raw = localStorage.getItem(AUTH_STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as AuthSession;
    if (!parsed.accessToken || !parsed.user) return null;
    return parsed;
  } catch {
    return null;
  }
}

function writeStoredAuth(auth: AuthSession) {
  localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(auth));
}

function clearStoredAuth() {
  localStorage.removeItem(AUTH_STORAGE_KEY);
}

function cloneResult(result: MeetingAnalysisResult): MeetingAnalysisResult {
  return JSON.parse(JSON.stringify(result));
}

function emptyToNull(value: string) {
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function usePublicExecutionManifest() {
  const [manifest, setManifest] = useState<PublicExecutionManifest | null>(null);

  useEffect(() => {
    fetch(`${RUN_PATH}execution.json`)
      .then((response) => response.ok ? response.json() : null)
      .then((payload) => {
        if (payload?.kind === "public_execution_hub") setManifest(payload);
      })
      .catch(() => setManifest(null));
  }, []);

  return manifest;
}

function App() {
  const [auth, setAuth] = useState<AuthSession | null>(() => readStoredAuth());
  const [authChecked, setAuthChecked] = useState(false);
  const [passwordChangeRequired, setPasswordChangeRequired] = useState(false);
  const [authView, setAuthView] = useState<AuthView>("login");
  const [loginForm, setLoginForm] = useState({ employee_no: "", password: "" });
  const [passwordForm, setPasswordForm] = useState({ current_password: "", new_password: "", confirm_password: "" });
  const [passwordResetRequestForm, setPasswordResetRequestForm] = useState<PasswordResetRequestForm>({ employee_no: "", email: "" });
  const [passwordResetConfirmForm, setPasswordResetConfirmForm] = useState<PasswordResetConfirmForm>({
    token: "",
    new_password: "",
    confirm_password: "",
  });
  const [projects, setProjects] = useState<Project[]>([]);
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [selectedProject, setSelectedProject] = useState("");
  const [selectedProjectDetail, setSelectedProjectDetail] = useState<ProjectDetail | null>(null);
  const [meetingId, setMeetingId] = useState("");
  const [review, setReview] = useState<ReviewPackage | null>(null);
  const [draftResult, setDraftResult] = useState<MeetingAnalysisResult | null>(null);
  const [distributionPreview, setDistributionPreview] = useState<EmailDistributionPreview | null>(null);
  const [distributionLogs, setDistributionLogs] = useState<EmailDistribution[]>([]);
  const [editReason, setEditReason] = useState("");
  const [message, setMessage] = useState("");
  const [activeView, setActiveView] = useState<AppView>("visual");
  const [adminUsers, setAdminUsers] = useState<User[]>([]);
  const [resourceProfiles, setResourceProfiles] = useState<ResourceProfile[]>([]);
  const [resourceAvailability, setResourceAvailability] = useState<ResourceAvailability[]>([]);
  const [resourceUsage, setResourceUsage] = useState<ResourceUsage[]>([]);
  const [costCandidates, setCostCandidates] = useState<ProjectCostCandidate[]>([]);
  const [recentMeetings, setRecentMeetings] = useState<MeetingStatusItem[]>([]);
  const [operationQueue, setOperationQueue] = useState<OperationQueueStatus | null>(null);
  const [knowledgeItems, setKnowledgeItems] = useState<ProjectKnowledgeItem[]>([]);
  const [knowledgeItemKind, setKnowledgeItemKind] = useState<KnowledgeItemKind>("all");
  const [knowledgeSearchTerm, setKnowledgeSearchTerm] = useState("");
  const [selectedAdminUserId, setSelectedAdminUserId] = useState("");
  const [adminCreateForm, setAdminCreateForm] = useState<UserCreateForm>({
    employee_no: "",
    name: "",
    email: "",
    role: "member",
    initial_password: "1234",
  });
  const [adminEditForm, setAdminEditForm] = useState<UserEditForm>({
    name: "",
    email: "",
    role: "member",
    status: "active",
  });
  const [adminResetPassword, setAdminResetPassword] = useState("1234");

  const canManageUsers = auth?.user.role === "admin";
  const canRunErpHandoff = auth?.user.role === "admin" || auth?.user.role === "finance";
  const canViewSensitiveStaffing = auth?.user.role === "admin" || auth?.user.role === "finance";
  const activeProject = useMemo(
    () => projects.find((project) => project.project_id === selectedProject),
    [projects, selectedProject],
  );
  const selectedAdminUser = useMemo(
    () => adminUsers.find((user) => user.user_id === selectedAdminUserId) ?? null,
    [adminUsers, selectedAdminUserId],
  );
  const hasUnsavedEdits = useMemo(
    () => Boolean(review && draftResult && JSON.stringify(review.result) !== JSON.stringify(draftResult)),
    [review, draftResult],
  );

  async function refresh() {
    if (!auth) return;
    const [projectRows, summary] = await Promise.all([
      api<Project[]>("/projects", undefined, auth.accessToken),
      api<Dashboard>("/dashboard/summary", undefined, auth.accessToken),
    ]);
    setProjects(projectRows);
    setDashboard(summary);
    if (!selectedProject && projectRows[0]) setSelectedProject(projectRows[0].project_id);
  }

  async function loadVisualData() {
    if (!auth) return;
    const today = formatLocalDate(new Date());
    const [profiles, availability, meetings, usage, costs, queueStatus] = await Promise.all([
      api<ResourceProfile[]>("/resources/profiles?status=active", undefined, auth.accessToken),
      api<ResourceAvailability[]>(`/resources/profiles/availability?starts_on=${today}&ends_on=${today}`, undefined, auth.accessToken),
      api<MeetingStatusItem[]>("/meetings?limit=8", undefined, auth.accessToken),
      api<ResourceUsage[]>("/resources/usage", undefined, auth.accessToken),
      api<ProjectCostCandidate[]>("/resources/cost-candidates?status=candidate", undefined, auth.accessToken),
      api<OperationQueueStatus>("/operations/queue-status", undefined, auth.accessToken),
    ]);
    setResourceProfiles(profiles);
    setResourceAvailability(availability);
    setRecentMeetings(meetings);
    setResourceUsage(usage);
    setCostCandidates(costs);
    setOperationQueue(queueStatus);
  }

  async function loadKnowledgeItems(projectId = selectedProject, itemKind = knowledgeItemKind, searchTerm = knowledgeSearchTerm) {
    if (!auth || !projectId) {
      setKnowledgeItems([]);
      return;
    }
    const params = new URLSearchParams({ limit: "20" });
    if (itemKind !== "all") params.set("item_kind", itemKind);
    const trimmedSearchTerm = searchTerm.trim();
    if (trimmedSearchTerm) params.set("q", trimmedSearchTerm);
    const rows = await api<ProjectKnowledgeItem[]>(
      `/projects/${projectId}/knowledge-items?${params.toString()}`,
      undefined,
      auth.accessToken,
    );
    setKnowledgeItems(rows);
  }

  async function reviewCostCandidate(costId: string, status: "approved" | "rejected") {
    if (!auth) return;
    const reviewed = await api<ProjectCostCandidate>(`/resources/cost-candidates/${costId}/status`, {
      method: "PATCH",
      body: JSON.stringify({
        status,
        review_note: status === "approved" ? "web visual approval" : "web visual rejection",
      }),
    }, auth.accessToken);
    setMessage(JSON.stringify({ cost_id: reviewed.cost_id, status: reviewed.status, reviewed_at: reviewed.reviewed_at }));
    await refresh();
    await loadVisualData();
  }

  async function runEmailRetryDue() {
    if (!auth) return;
    const rows = await api<EmailDistribution[]>("/distributions/retry-due", {
      method: "POST",
      body: JSON.stringify({ limit: 10 }),
    }, auth.accessToken);
    setMessage(JSON.stringify({
      email_retry_due_processed: rows.length,
      distribution_ids: rows.map((row) => row.distribution_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runErpHandoffSendDue() {
    if (!auth) return;
    const rows = await api<ProjectCostHandoff[]>("/resources/cost-handoffs/send-due", {
      method: "POST",
      body: JSON.stringify({ limit: 10 }),
    }, auth.accessToken);
    setMessage(JSON.stringify({
      erp_handoff_processed: rows.length,
      handoff_ids: rows.map((row) => row.handoff_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runOverdueRiskPromotion() {
    if (!auth) return;
    const result = await api<DelayedTaskRiskPromotion>("/tasks/overdue-risks", {
      method: "POST",
    }, auth.accessToken);
    setMessage(JSON.stringify({
      scanned_overdue_tasks: result.scanned_overdue_tasks,
      created_risks: result.created_risks.length,
      risk_ids: result.created_risks.map((risk) => risk.risk_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runCostRiskPromotion() {
    if (!auth) return;
    const result = await api<CostCandidateRiskPromotion>(
      "/resources/cost-candidates/overrun-risks?threshold_amount=1000000&currency=KRW",
      { method: "POST" },
      auth.accessToken,
    );
    setMessage(JSON.stringify({
      scanned_cost_candidates: result.scanned_cost_candidates,
      threshold_amount: result.threshold_amount,
      currency: result.currency,
      created_risks: result.created_risks.length,
      risk_ids: result.created_risks.map((risk) => risk.risk_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runResourceConflictRiskPromotion() {
    if (!auth) return;
    const result = await api<ResourceConflictRiskPromotion>("/resources/allocations/conflict-risks", {
      method: "POST",
    }, auth.accessToken);
    setMessage(JSON.stringify({
      scanned_conflicts: result.scanned_conflicts,
      created_risks: result.created_risks.length,
      risk_ids: result.created_risks.map((risk) => risk.risk_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runUnassignedResourceDemandRiskPromotion() {
    if (!auth) return;
    const result = await api<UnassignedResourceDemandRiskPromotion>(
      "/resources/demands/unassigned-risks?due_within_days=0",
      { method: "POST" },
      auth.accessToken,
    );
    setMessage(JSON.stringify({
      scanned_demands: result.scanned_demands,
      due_within_days: result.due_within_days,
      created_risks: result.created_risks.length,
      risk_ids: result.created_risks.map((risk) => risk.risk_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function runResourceUsageOverrunRiskPromotion() {
    if (!auth) return;
    const result = await api<ResourceUsageOverrunRiskPromotion>(
      "/resources/usage/overrun-risks?threshold_ratio=1",
      { method: "POST" },
      auth.accessToken,
    );
    setMessage(JSON.stringify({
      scanned_usage_entries: result.scanned_usage_entries,
      threshold_ratio: result.threshold_ratio,
      created_risks: result.created_risks.length,
      risk_ids: result.created_risks.map((risk) => risk.risk_id).slice(0, 5),
    }));
    await refresh();
    await loadVisualData();
  }

  async function loadAdminUsers() {
    if (!auth || !canManageUsers) return;
    const rows = await api<User[]>("/admin/users", undefined, auth.accessToken);
    setAdminUsers(rows);
    if (!selectedAdminUserId && rows[0]) {
      setSelectedAdminUserId(rows[0].user_id);
    } else if (selectedAdminUserId && !rows.some((user) => user.user_id === selectedAdminUserId)) {
      setSelectedAdminUserId(rows[0]?.user_id ?? "");
    }
  }

  async function createAdminUser() {
    if (!auth) return;
    const created = await api<User>("/admin/users", {
      method: "POST",
      body: JSON.stringify({
        ...adminCreateForm,
        email: emptyToNull(adminCreateForm.email),
      }),
    }, auth.accessToken);
    setAdminUsers((rows) => [created, ...rows.filter((user) => user.user_id !== created.user_id)]);
    setSelectedAdminUserId(created.user_id);
    setAdminCreateForm({
      employee_no: "",
      name: "",
      email: "",
      role: "member",
      initial_password: "1234",
    });
    setMessage(JSON.stringify({ created_user: created.employee_no, status: created.status }));
  }

  async function saveAdminUser() {
    if (!auth || !selectedAdminUser) return;
    const updated = await api<User>(`/admin/users/${selectedAdminUser.user_id}`, {
      method: "PUT",
      body: JSON.stringify({
        ...adminEditForm,
        email: emptyToNull(adminEditForm.email),
      }),
    }, auth.accessToken);
    setAdminUsers((rows) => rows.map((user) => (user.user_id === updated.user_id ? updated : user)));
    setMessage(JSON.stringify({ updated_user: updated.employee_no, role: updated.role, status: updated.status }));
  }

  async function resetAdminUserPassword() {
    if (!auth || !selectedAdminUser) return;
    const result = await api<{ user: User; password_change_required: boolean; revoked_tokens: number }>(
      `/admin/users/${selectedAdminUser.user_id}/reset-password`,
      {
        method: "POST",
        body: JSON.stringify({
          new_password: adminResetPassword,
          force_password_change: true,
        }),
      },
      auth.accessToken,
    );
    setAdminUsers((rows) => rows.map((user) => (user.user_id === result.user.user_id ? result.user : user)));
    setAdminResetPassword("1234");
    setMessage(JSON.stringify({
      reset_user: result.user.employee_no,
      password_change_required: result.password_change_required,
      revoked_tokens: result.revoked_tokens,
    }));
  }

  async function loadReview() {
    if (!auth) return;
    if (!meetingId.trim()) return;
    const nextReview = await api<ReviewPackage>(`/meetings/${meetingId.trim()}/review-package`, undefined, auth.accessToken);
    setReview(nextReview);
    setDraftResult(cloneResult(nextReview.result));
    setDistributionPreview(null);
    setDistributionLogs([]);
    setEditReason("");
  }

  async function loadDistributionPreview() {
    if (!auth) return;
    if (!meetingId.trim()) return;
    const targetMeetingId = meetingId.trim();
    const [preview, logs] = await Promise.all([
      api<EmailDistributionPreview>(`/meetings/${targetMeetingId}/distribution-preview`, undefined, auth.accessToken),
      api<EmailDistribution[]>(`/meetings/${targetMeetingId}/distributions`, undefined, auth.accessToken),
    ]);
    setDistributionPreview(preview);
    setDistributionLogs(logs);
  }

  async function loadDistributionLogs(targetMeetingId = meetingId.trim()) {
    if (!auth || !targetMeetingId) return;
    const logs = await api<EmailDistribution[]>(`/meetings/${targetMeetingId}/distributions`, undefined, auth.accessToken);
    setDistributionLogs(logs);
  }

  async function distributeMeeting() {
    if (!auth || !distributionPreview) return;
    if (distributionPreview.recipients.length === 0) {
      setMessage("프로젝트 구성원 이메일이 없습니다.");
      return;
    }
    const result = await api<EmailDistribution>(`/meetings/${distributionPreview.meeting.meeting_id}/distribute`, {
      method: "POST",
      body: JSON.stringify({
        subject: distributionPreview.subject,
        body: distributionPreview.body,
      }),
    }, auth.accessToken);
    setDistributionPreview(null);
    setDistributionLogs([result]);
    setMessage(JSON.stringify({
      distribution_id: result.distribution_id,
      status: result.status,
      recipients: result.attempts.length,
    }));
    await refresh();
    await loadReview().catch(() => undefined);
    await loadDistributionLogs(result.meeting_id);
  }

  async function saveEdits() {
    if (!auth) return;
    if (!review || !draftResult) return;
    const updated = await api<ReviewPackage>(`/meetings/analyses/${review.analysis_id}/review-edits`, {
      method: "PUT",
      body: JSON.stringify({
        result: draftResult,
        edit_reason: emptyToNull(editReason),
      }),
    }, auth.accessToken);
    setReview(updated);
    setDraftResult(cloneResult(updated.result));
    setEditReason("");
    setMessage(JSON.stringify({ analysis_id: updated.analysis_id, status: updated.analysis_status, saved: true }));
    await refresh();
  }

  async function approve() {
    if (!auth) return;
    if (!review) return;
    const result = await api(`/approvals/meeting-analyses/${review.analysis_id}/approve`, { method: "POST" }, auth.accessToken);
    setMessage(JSON.stringify(result));
    await loadReview();
    await refresh();
  }

  function resetDraft() {
    if (!review) return;
    setDraftResult(cloneResult(review.result));
    setEditReason("");
  }

  useEffect(() => {
    const stored = readStoredAuth();
    if (!stored) {
      setAuthChecked(true);
      return;
    }
    api<User>("/users/me", undefined, stored.accessToken)
      .then((user) => {
        const verified = { ...stored, user };
        setAuth(verified);
        writeStoredAuth(verified);
        setPasswordChangeRequired(user.status === "password_change_required");
        setAuthChecked(true);
      })
      .catch(() => {
        clearStoredAuth();
        setAuth(null);
        setAuthChecked(true);
      });
  }, []);

  useEffect(() => {
    if (authChecked && auth && !passwordChangeRequired) {
      refresh().catch((error) => setMessage(error.message));
    }
  }, [authChecked, auth?.accessToken, passwordChangeRequired]);

  useEffect(() => {
    if (authChecked && auth && !passwordChangeRequired && activeView === "admin" && canManageUsers) {
      loadAdminUsers().catch((error) => setMessage(error.message));
    }
  }, [authChecked, auth?.accessToken, passwordChangeRequired, activeView, canManageUsers]);

  useEffect(() => {
    if (authChecked && auth && !passwordChangeRequired && activeView === "visual") {
      loadVisualData().catch((error) => setMessage(error.message));
    }
  }, [authChecked, auth?.accessToken, passwordChangeRequired, activeView]);

  useEffect(() => {
    if (!authChecked || !auth || passwordChangeRequired || activeView !== "visual" || !selectedProject) {
      setSelectedProjectDetail(null);
      return;
    }
    let cancelled = false;
    api<ProjectDetail>(`/projects/${encodeURIComponent(selectedProject)}/detail`, undefined, auth.accessToken)
      .then((detail) => {
        if (!cancelled) setSelectedProjectDetail(detail);
      })
      .catch((error) => {
        if (!cancelled) {
          setSelectedProjectDetail(null);
          setMessage(error.message);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [authChecked, auth?.accessToken, passwordChangeRequired, activeView, selectedProject]);

  useEffect(() => {
    if (authChecked && auth && !passwordChangeRequired && activeView === "visual") {
      loadKnowledgeItems().catch((error) => setMessage(error.message));
    }
  }, [authChecked, auth?.accessToken, passwordChangeRequired, activeView, selectedProject, knowledgeItemKind]);

  useEffect(() => {
    if (!selectedAdminUser) return;
    setAdminEditForm({
      name: selectedAdminUser.name,
      email: selectedAdminUser.email ?? "",
      role: selectedAdminUser.role as UserRole,
      status: selectedAdminUser.status as UserStatus,
    });
  }, [selectedAdminUser?.user_id, selectedAdminUser?.name, selectedAdminUser?.email, selectedAdminUser?.role, selectedAdminUser?.status]);

  async function login() {
    const result = await api<LoginResponse>("/users/login", {
      method: "POST",
      body: JSON.stringify(loginForm),
    });
    const nextAuth = {
      accessToken: result.access_token,
      expiresAt: result.expires_at,
      user: result.user,
    };
    setAuth(nextAuth);
    writeStoredAuth(nextAuth);
    setPasswordChangeRequired(result.password_change_required);
    setLoginForm({ employee_no: "", password: "" });
    setMessage("");
  }

  async function requestPasswordReset() {
    const result = await api<PasswordResetRequestResponse>("/users/password-reset/request", {
      method: "POST",
      body: JSON.stringify(passwordResetRequestForm),
    });
    setPasswordResetConfirmForm({
      token: result.reset_token ?? "",
      new_password: "",
      confirm_password: "",
    });
    setAuthView("reset-confirm");
    setMessage(JSON.stringify({
      employee_no: result.employee_no,
      delivery_status: result.delivery_status,
      expires_at: result.expires_at,
    }));
  }

  async function confirmPasswordReset() {
    if (passwordResetConfirmForm.new_password !== passwordResetConfirmForm.confirm_password) {
      setMessage("새 비밀번호가 일치하지 않습니다.");
      return;
    }
    const result = await api<PasswordResetConfirmResponse>("/users/password-reset/confirm", {
      method: "POST",
      body: JSON.stringify({
        token: passwordResetConfirmForm.token,
        new_password: passwordResetConfirmForm.new_password,
      }),
    });
    setPasswordResetRequestForm({ employee_no: "", email: "" });
    setPasswordResetConfirmForm({ token: "", new_password: "", confirm_password: "" });
    setAuthView("login");
    setMessage(JSON.stringify({ employee_no: result.employee_no, status: result.status, password_reset: true }));
  }

  async function changePassword() {
    if (!auth) return;
    if (passwordForm.new_password !== passwordForm.confirm_password) {
      setMessage("새 비밀번호가 일치하지 않습니다.");
      return;
    }
    await api<{ employee_no: string; status: string }>("/users/password/change", {
      method: "POST",
      body: JSON.stringify({
        employee_no: auth.user.employee_no,
        current_password: passwordForm.current_password,
        new_password: passwordForm.new_password,
      }),
    }, auth.accessToken);
    const result = await api<LoginResponse>("/users/login", {
      method: "POST",
      body: JSON.stringify({
        employee_no: auth.user.employee_no,
        password: passwordForm.new_password,
      }),
    });
    const nextAuth = {
      accessToken: result.access_token,
      expiresAt: result.expires_at,
      user: result.user,
    };
    setAuth(nextAuth);
    writeStoredAuth(nextAuth);
    setPasswordChangeRequired(false);
    setPasswordForm({ current_password: "", new_password: "", confirm_password: "" });
    setMessage("");
  }

  async function logout() {
    if (auth) {
      await api("/users/logout", { method: "POST" }, auth.accessToken).catch(() => undefined);
    }
    clearStoredAuth();
    setAuth(null);
    setProjects([]);
    setDashboard(null);
    setReview(null);
    setDraftResult(null);
    setAdminUsers([]);
    setSelectedAdminUserId("");
    setKnowledgeItems([]);
    setKnowledgeItemKind("all");
    setActiveView("visual");
    setPasswordChangeRequired(false);
  }

  if (!authChecked) {
    return (
      <main className="auth-shell">
        <div className="auth-panel">
          <h1>AI-PMS</h1>
        </div>
      </main>
    );
  }

  if (!auth) {
    return (
      <AuthPanel
        authView={authView}
        loginForm={loginForm}
        passwordResetRequestForm={passwordResetRequestForm}
        passwordResetConfirmForm={passwordResetConfirmForm}
        message={message}
        onAuthViewChange={setAuthView}
        onLoginFormChange={setLoginForm}
        onPasswordResetRequestFormChange={setPasswordResetRequestForm}
        onPasswordResetConfirmFormChange={setPasswordResetConfirmForm}
        onLogin={() => login().catch((error) => setMessage(error.message))}
        onRequestPasswordReset={() => requestPasswordReset().catch((error) => setMessage(error.message))}
        onConfirmPasswordReset={() => confirmPasswordReset().catch((error) => setMessage(error.message))}
      />
    );
  }

  if (passwordChangeRequired) {
    return (
      <PasswordChangePanel
        user={auth.user}
        passwordForm={passwordForm}
        message={message}
        onPasswordFormChange={setPasswordForm}
        onChangePassword={() => changePassword().catch((error) => setMessage(error.message))}
        onLogout={() => logout().catch((error) => setMessage(error.message))}
      />
    );
  }

  return (
    <div className="meetflow-shell">
      <aside className="meetflow-sidebar">
        <div className="meetflow-brand">
          <span className="brand-mark">M</span>
          <strong>{PRODUCT_BRAND_NAME}</strong>
        </div>
        <nav className="meetflow-nav">
          <button className={activeView === "visual" ? "active" : ""} type="button" onClick={() => setActiveView("visual")}>
            <BarChart3 size={18} />
            <span>시각화</span>
          </button>
          <button className={activeView === "review" ? "active" : ""} type="button" onClick={() => setActiveView("review")}>
            <ClipboardList size={18} />
            <span>검토</span>
          </button>
          {canManageUsers && (
            <button className={activeView === "admin" ? "active" : ""} type="button" onClick={() => setActiveView("admin")}>
              <Users size={18} />
              <span>사용자</span>
            </button>
          )}
        </nav>
        <div className="sidebar-spacer" />
        <a className="sidebar-utility" href={RUN_PATH} target="_blank" rel="noreferrer">
          <Activity size={17} />
          <span>실행 허브</span>
        </a>
        <a className="sidebar-utility" href={APK_DOWNLOAD_PATH} target="_blank" rel="noreferrer">
          <Download size={17} />
          <span>APK 다운로드</span>
        </a>
        <a className="sidebar-utility" href={HANDOFF_PATH} target="_blank" rel="noreferrer">
          <BookOpen size={17} />
          <span>파트 전달안</span>
        </a>
      </aside>

      <section className="meetflow-main">
        <div className="meetflow-topbar">
          <button className="top-icon" type="button" aria-label="메뉴">
            <Menu size={18} />
          </button>
          <div className="top-search">
            <Search size={16} />
            <span>업무 검색...</span>
          </div>
          <button className="top-icon" type="button" aria-label="새로고침" onClick={() => refresh().then(() => activeView === "admin" ? loadAdminUsers() : activeView === "visual" ? loadVisualData() : undefined).catch((error) => setMessage(error.message))}>
            <RefreshCw size={18} />
          </button>
          <button className="top-icon" type="button" aria-label="로그아웃" onClick={() => logout().catch((error) => setMessage(error.message))}>
            <LogOut size={18} />
          </button>
          <div className="profile-chip">
            <span>{auth.user.name}</span>
            <small>{DEMO_COMPANY_NAME} · {auth.user.role}</small>
            <ChevronDown size={14} />
          </div>
        </div>

        <div className="meetflow-body">
          <section className="metrics">
        <Metric icon={<Database size={18} />} label="프로젝트" value={dashboard?.projects ?? 0} />
        <Metric icon={<ClipboardList size={18} />} label="회의" value={dashboard?.meetings ?? 0} />
        <Metric icon={<Check size={18} />} label="검토 대기" value={dashboard?.pending_reviews ?? 0} />
        <Metric icon={<Clock size={18} />} label="기한 임박" value={dashboard?.overdue_tasks ?? 0} />
        <Metric icon={<AlertTriangle size={18} />} label="오픈 리스크" value={dashboard?.unresolved_risks ?? 0} />
        <Metric icon={<Users size={18} />} label="자원 요청" value={dashboard?.resource_demands ?? 0} />
        <Metric icon={<Ban size={18} />} label="자원 충돌" value={dashboard?.resource_conflicts ?? 0} />
        <Metric icon={<BarChart3 size={18} />} label="비용 후보" value={dashboard?.cost_candidates ?? 0} />
        <Metric icon={<Mail size={18} />} label="배포 실패" value={dashboard?.distribution_failures ?? 0} />
        <Metric icon={<Layers size={18} />} label="지식 항목" value={dashboard?.knowledge_items ?? 0} />
          </section>

      {activeView === "visual" ? (
        <VisualConsole
          dashboard={dashboard}
          projects={projects}
          review={review}
          resourceProfiles={resourceProfiles}
          resourceAvailability={resourceAvailability}
          resourceUsage={resourceUsage}
          costCandidates={costCandidates}
          distributionLogs={distributionLogs}
          recentMeetings={recentMeetings}
          operationQueue={operationQueue}
          selectedProject={selectedProject}
          selectedProjectDetail={selectedProjectDetail}
          knowledgeItems={knowledgeItems}
          knowledgeItemKind={knowledgeItemKind}
          knowledgeSearchTerm={knowledgeSearchTerm}
          canRunErpHandoff={canRunErpHandoff}
          canViewSensitiveStaffing={canViewSensitiveStaffing}
          onKnowledgeProjectChange={setSelectedProject}
          onKnowledgeItemKindChange={setKnowledgeItemKind}
          onKnowledgeSearchTermChange={setKnowledgeSearchTerm}
          onRefreshKnowledge={() => loadKnowledgeItems().catch((error) => setMessage(error.message))}
          onReviewCostCandidate={(costId, status) => reviewCostCandidate(costId, status).catch((error) => setMessage(error.message))}
          onRunOverdueRiskPromotion={() => runOverdueRiskPromotion().catch((error) => setMessage(error.message))}
          onRunCostRiskPromotion={() => runCostRiskPromotion().catch((error) => setMessage(error.message))}
          onRunResourceConflictRiskPromotion={() => runResourceConflictRiskPromotion().catch((error) => setMessage(error.message))}
          onRunUnassignedResourceDemandRiskPromotion={() => runUnassignedResourceDemandRiskPromotion().catch((error) => setMessage(error.message))}
          onRunResourceUsageOverrunRiskPromotion={() => runResourceUsageOverrunRiskPromotion().catch((error) => setMessage(error.message))}
          onRunEmailRetryDue={() => runEmailRetryDue().catch((error) => setMessage(error.message))}
          onRunErpHandoffSendDue={() => runErpHandoffSendDue().catch((error) => setMessage(error.message))}
          onOpenMeeting={(targetMeetingId) => {
            setMeetingId(targetMeetingId);
            setActiveView("review");
          }}
        />
      ) : activeView === "review" ? (
        <section className="workspace">
          <aside>
            <h2>Projects</h2>
            <select value={selectedProject} onChange={(event) => setSelectedProject(event.target.value)}>
              <option value="">선택</option>
              {projects.map((project) => (
                <option key={project.project_id} value={project.project_id}>
                  {project.name}
                </option>
              ))}
            </select>
            {activeProject && (
              <dl>
                <dt>Project ID</dt>
                <dd>{activeProject.project_id}</dd>
                <dt>Status</dt>
                <dd>{activeProject.status}</dd>
              </dl>
            )}
          </aside>

          <section className="review">
            <div className="toolbar">
              <input
                value={meetingId}
                onChange={(event) => setMeetingId(event.target.value)}
                placeholder="Meeting ID"
              />
              <button onClick={() => loadReview().catch((error) => setMessage(error.message))}>
                <ClipboardList size={16} /> 검토 불러오기
              </button>
              <button disabled={!review?.capabilities.can_edit || !hasUnsavedEdits} onClick={() => saveEdits().catch((error) => setMessage(error.message))}>
                <Save size={16} /> 저장
              </button>
              <button className="secondary" disabled={!hasUnsavedEdits} onClick={resetDraft}>
                <RotateCcw size={16} /> 되돌리기
              </button>
              <button disabled={!review?.capabilities.can_approve || hasUnsavedEdits} onClick={() => approve().catch((error) => setMessage(error.message))}>
                <Send size={16} /> 승인
              </button>
              <button className="secondary" disabled={!review?.capabilities.can_distribute || hasUnsavedEdits} onClick={() => loadDistributionPreview().catch((error) => setMessage(error.message))}>
                <Mail size={16} /> 배포 미리보기
              </button>
            </div>

            {review && draftResult ? (
              <ReviewPanel
                review={review}
                draft={draftResult}
                editReason={editReason}
                onDraftChange={setDraftResult}
                onEditReasonChange={setEditReason}
              />
            ) : (
              <div className="empty">회의록 검토 패키지를 불러오세요.</div>
            )}
            {distributionPreview && (
              <DistributionPanel
                preview={distributionPreview}
                logs={distributionLogs}
                onPreviewChange={setDistributionPreview}
                onSend={() => distributeMeeting().catch((error) => setMessage(error.message))}
                onRefreshLogs={() => loadDistributionLogs(distributionPreview.meeting.meeting_id).catch((error) => setMessage(error.message))}
              />
            )}
            {!distributionPreview && distributionLogs.length > 0 && <DistributionLogPanel logs={distributionLogs} />}
          </section>
        </section>
      ) : (
        <AdminUsersPanel
          users={adminUsers}
          selectedUser={selectedAdminUser}
          selectedUserId={selectedAdminUserId}
          createForm={adminCreateForm}
          editForm={adminEditForm}
          resetPassword={adminResetPassword}
          onSelectUser={setSelectedAdminUserId}
          onCreateFormChange={setAdminCreateForm}
          onEditFormChange={setAdminEditForm}
          onResetPasswordChange={setAdminResetPassword}
          onCreate={() => createAdminUser().catch((error) => setMessage(error.message))}
          onSave={() => saveAdminUser().catch((error) => setMessage(error.message))}
          onResetPassword={() => resetAdminUserPassword().catch((error) => setMessage(error.message))}
          onRefresh={() => loadAdminUsers().catch((error) => setMessage(error.message))}
        />
      )}

          {message && <pre className="message">{message}</pre>}
        </div>
      </section>
    </div>
  );
}

const MEETING_STATUS_LABELS: Record<string, string> = {
  created: "생성",
  upload_requested: "업로드 요청",
  uploaded: "업로드 완료",
  analysis_queued: "분석 대기",
  analyzing: "분석중",
  review_required: "검토 대기",
  approved: "승인",
  distributed: "배포",
  upload_failed: "업로드 실패",
  analysis_failed: "분석 실패",
  review_rejected: "검토 반려",
  distribution_failed: "배포 실패",
};

function meetingStatusTone(status: string) {
  if (status.endsWith("_failed") || status === "review_rejected") return "danger";
  if (status === "review_required") return "warn";
  if (status === "approved" || status === "distributed") return "done";
  if (status === "analyzing" || status === "analysis_queued" || status === "uploaded") return "progress";
  return "idle";
}

function formatShortDateTime(value: string) {
  return new Intl.DateTimeFormat("ko-KR", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function formatLocalDate(value: Date) {
  const local = new Date(value.getTime() - value.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function formatCurrency(amount: number, currency: string) {
  return new Intl.NumberFormat("ko-KR", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatPercent(value: number) {
  return `${new Intl.NumberFormat("ko-KR", { maximumFractionDigits: 1 }).format(value)}%`;
}

function formatMm(value: number) {
  return `${new Intl.NumberFormat("ko-KR", { maximumFractionDigits: 1 }).format(value)} M/M`;
}

function projectRoleLabel(role: string) {
  const labels: Record<string, string> = {
    project_lead: "PM",
    technical_lead: "PL",
    developer: "DEV",
    member: "Member",
  };
  return labels[role] ?? role;
}

function knowledgeKindLabel(kind: string) {
  const labels: Record<string, string> = {
    all: "All",
    summary: "Summary",
    decision: "Decision",
    action_item: "Action Item",
    risk: "Risk",
    required_resource: "Required Resource",
  };
  return labels[kind] ?? kind;
}

function formatEvidenceTime(ms?: number | null) {
  if (ms === undefined || ms === null) return "";
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = String(totalSeconds % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function formatEvidenceRef(ref: EvidenceRef) {
  const label = "근거 구간";
  const start = formatEvidenceTime(ref.start_ms);
  const end = formatEvidenceTime(ref.end_ms);
  const range = start && end ? `${start}-${end}` : start || end;
  const segment = ref.segment_id ? ` · ${ref.segment_id}` : "";
  return range ? `${label} · ${range}${segment}` : `${label}${segment}`;
}

function LegacyVisualConsole({
  dashboard,
  projects,
  review,
  resourceProfiles,
  resourceAvailability,
  resourceUsage,
  costCandidates,
  distributionLogs,
  recentMeetings,
  operationQueue,
  selectedProject,
  knowledgeItems,
  knowledgeItemKind,
  knowledgeSearchTerm,
  canRunErpHandoff,
  onKnowledgeProjectChange,
  onKnowledgeItemKindChange,
  onKnowledgeSearchTermChange,
  onRefreshKnowledge,
  onReviewCostCandidate,
  onRunOverdueRiskPromotion,
  onRunCostRiskPromotion,
  onRunResourceConflictRiskPromotion,
  onRunUnassignedResourceDemandRiskPromotion,
  onRunResourceUsageOverrunRiskPromotion,
  onRunEmailRetryDue,
  onRunErpHandoffSendDue,
  onOpenMeeting,
}: {
  dashboard: Dashboard | null;
  projects: Project[];
  review: ReviewPackage | null;
  resourceProfiles: ResourceProfile[];
  resourceAvailability: ResourceAvailability[];
  resourceUsage: ResourceUsage[];
  costCandidates: ProjectCostCandidate[];
  distributionLogs: EmailDistribution[];
  recentMeetings: MeetingStatusItem[];
  operationQueue: OperationQueueStatus | null;
  selectedProject: string;
  selectedProjectDetail: ProjectDetail | null;
  knowledgeItems: ProjectKnowledgeItem[];
  knowledgeItemKind: KnowledgeItemKind;
  knowledgeSearchTerm: string;
  canRunErpHandoff: boolean;
  canViewSensitiveStaffing: boolean;
  onKnowledgeProjectChange: (projectId: string) => void;
  onKnowledgeItemKindChange: (kind: KnowledgeItemKind) => void;
  onKnowledgeSearchTermChange: (searchTerm: string) => void;
  onRefreshKnowledge: () => void;
  onReviewCostCandidate: (costId: string, status: "approved" | "rejected") => void;
  onRunOverdueRiskPromotion: () => void;
  onRunCostRiskPromotion: () => void;
  onRunResourceConflictRiskPromotion: () => void;
  onRunUnassignedResourceDemandRiskPromotion: () => void;
  onRunResourceUsageOverrunRiskPromotion: () => void;
  onRunEmailRetryDue: () => void;
  onRunErpHandoffSendDue: () => void;
  onOpenMeeting: (meetingId: string) => void;
}) {
  const result = review?.result;
  const latestDistribution = distributionLogs[0];
  const availableResources = resourceAvailability.filter((resource) => resource.is_available).length;
  const blockedResources = resourceAvailability.filter((resource) => !resource.is_available).length;
  const totalCandidateCost = costCandidates.reduce((sum, candidate) => sum + candidate.amount, 0);
  const candidateCurrency = costCandidates[0]?.currency ?? "KRW";
  const totalReviewItems =
    (result?.action_items.length ?? 0) +
    (result?.decisions.length ?? 0) +
    (result?.risks.length ?? 0) +
    (result?.required_resources.length ?? 0);
  const emailQueue = operationQueue?.email_distributions;
  const erpQueue = operationQueue?.erp_handoffs;
  const selectedKnowledgeProject = projects.find((project) => project.project_id === selectedProject) ?? null;
  const attentionItems = [
    { label: "Overdue Tasks", detail: "due date passed", value: dashboard?.overdue_tasks ?? 0 },
    { label: "Open Risks", detail: "candidate/open/active", value: dashboard?.unresolved_risks ?? 0 },
    { label: "Resource Conflicts", detail: "allocation conflicts", value: dashboard?.resource_conflicts ?? 0 },
    { label: "Distribution Failures", detail: "failed/retry wait", value: dashboard?.distribution_failures ?? 0 },
  ];
  const pipeline = [
    { label: "Record", value: dashboard?.meetings ?? 0, icon: <Mic size={18} /> },
    { label: "Analyze", value: review ? 1 : 0, icon: <Cpu size={18} /> },
    { label: "Review", value: dashboard?.pending_reviews ?? 0, icon: <ClipboardList size={18} /> },
    { label: "Allocate", value: dashboard?.resource_demands ?? 0, icon: <Network size={18} /> },
    { label: "Cost", value: dashboard?.cost_candidates ?? costCandidates.length, icon: <BarChart3 size={18} /> },
    { label: "Distribute", value: latestDistribution ? latestDistribution.attempts.length : 0, icon: <Mail size={18} /> },
  ];

  return (
    <section className="visual-shell">
      <section className="visual-hero">
        <div className="hero-copy">
          <span className="eyebrow"><Sparkles size={14} /> AI-PMS Control Plane</span>
          <h2>회의 기록에서 프로젝트 실행까지</h2>
          <p>Project_ID 중심으로 회의, 분석, 승인, 자원, 배포 흐름을 연결합니다.</p>
        </div>
        <div className="hero-orbit" aria-hidden="true">
          <div className="orbit-core"><Activity size={30} /></div>
          <span>STT</span>
          <span>LLM</span>
          <span>PMS</span>
          <span>ERP</span>
        </div>
      </section>

      <section className="visual-grid">
        <section className="visual-card flow-card">
          <div className="section-title">
            <h2>운영 흐름</h2>
            <span className="status-pill active">live</span>
          </div>
          <div className="pipeline">
            {pipeline.map((step) => (
              <div className="pipeline-step" key={step.label}>
                <span>{step.icon}</span>
                <strong>{step.value}</strong>
                <small>{step.label}</small>
              </div>
            ))}
          </div>
        </section>

        <section className="visual-card ops-card">
          <div className="section-title">
            <h2>Operations Queue</h2>
            <span className="ops-actions">
              <button
                className="icon-button"
                title="Email due retry 실행"
                aria-label="Email due retry 실행"
                onClick={onRunEmailRetryDue}
              >
                <RefreshCw size={14} />
              </button>
              <button
                className="icon-button"
                title="ERP handoff due 송신"
                aria-label="ERP handoff due 송신"
                disabled={!canRunErpHandoff}
                onClick={onRunErpHandoffSendDue}
              >
                <Send size={14} />
              </button>
              <AlertTriangle size={18} />
            </span>
          </div>
          <div className="ops-list">
            <div className="ops-row">
              <span className={`status-dot ${(emailQueue?.attention_count ?? 0) > 0 ? "warn" : "done"}`} />
              <span className="ops-main">
                <b>Email Delivery</b>
                <small>retry due {emailQueue?.retry_due ?? 0} · failed {emailQueue?.status_counts.failed ?? 0}</small>
              </span>
              <strong>{emailQueue?.attention_count ?? 0}</strong>
            </div>
            <div className="ops-row">
              <span className={`status-dot ${(erpQueue?.attention_count ?? 0) > 0 ? "warn" : "done"}`} />
              <span className="ops-main">
                <b>ERP Handoff</b>
                <small>queued {erpQueue?.status_counts.queued ?? 0} · retry due {erpQueue?.retry_due ?? 0}</small>
              </span>
              <strong>{erpQueue?.attention_count ?? 0}</strong>
            </div>
          </div>
          <div className="ops-meta">
            <span>email {emailQueue?.next_retry_at ? formatShortDateTime(emailQueue.next_retry_at) : "no retry"}</span>
            <span>erp {erpQueue?.next_retry_at ? formatShortDateTime(erpQueue.next_retry_at) : "no retry"}</span>
          </div>
        </section>

        <section className="visual-card attention-card">
          <div className="section-title">
            <h2>Attention KPI</h2>
            <span className="ops-actions">
              <button
                className="icon-button"
                title="지연 업무를 리스크 후보로 생성"
                aria-label="지연 업무를 리스크 후보로 생성"
                onClick={onRunOverdueRiskPromotion}
              >
                <AlertTriangle size={14} />
              </button>
              <AlertTriangle size={18} />
            </span>
          </div>
          <div className="attention-list">
            {attentionItems.map((item) => (
              <div className="attention-row" key={item.label}>
                <span className={`status-dot ${item.value > 0 ? "warn" : "done"}`} />
                <span className="attention-main">
                  <b>{item.label}</b>
                  <small>{item.detail}</small>
                </span>
                <strong>{item.value}</strong>
              </div>
            ))}
          </div>
        </section>

        <section className="visual-card meeting-status-card">
          <div className="section-title">
            <h2>최근 회의 처리 상태</h2>
            <Activity size={18} />
          </div>
          <div className="meeting-status-list">
            {recentMeetings.map((meeting) => (
              <button
                className="meeting-status-row"
                key={meeting.meeting_id}
                onClick={() => onOpenMeeting(meeting.meeting_id)}
                aria-label={`${meeting.title} 검토 화면 열기`}
              >
                <span className={`status-dot ${meetingStatusTone(meeting.status)}`} />
                <span className="meeting-status-main">
                  <b>{meeting.title}</b>
                  <small>{meeting.project_name} · {meeting.meeting_id}</small>
                </span>
                <span className="meeting-status-meta">
                  <i>{MEETING_STATUS_LABELS[meeting.status] ?? meeting.status}</i>
                  <small>{meeting.latest_analysis_status ?? "analysis 없음"}</small>
                  <small>{formatShortDateTime(meeting.created_at)}</small>
                </span>
              </button>
            ))}
            {recentMeetings.length === 0 && <p className="muted">최근 회의가 없습니다.</p>}
          </div>
        </section>

        <section className="visual-card knowledge-card">
          <div className="section-title">
            <h2>Project Knowledge</h2>
            <BookOpen size={18} />
          </div>
          <form
            className="knowledge-toolbar"
            onSubmit={(event) => {
              event.preventDefault();
              onRefreshKnowledge();
            }}
          >
            <label>
              <span>Project</span>
              <select value={selectedProject} onChange={(event) => onKnowledgeProjectChange(event.target.value)}>
                <option value="">선택</option>
                {projects.map((project) => (
                  <option key={project.project_id} value={project.project_id}>
                    {project.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Kind</span>
              <select value={knowledgeItemKind} onChange={(event) => onKnowledgeItemKindChange(event.target.value as KnowledgeItemKind)}>
                {KNOWLEDGE_ITEM_KINDS.map((kind) => (
                  <option key={kind} value={kind}>{knowledgeKindLabel(kind)}</option>
                ))}
              </select>
            </label>
            <label>
              <span>Search</span>
              <input
                value={knowledgeSearchTerm}
                onChange={(event) => onKnowledgeSearchTermChange(event.target.value)}
                placeholder="제목, 내용, 태그, 근거"
              />
            </label>
            <button type="submit" className="secondary" disabled={!selectedProject}>
              <Search size={16} /> 조회
            </button>
          </form>
          <div className="knowledge-headline">
            <strong>{selectedKnowledgeProject?.name ?? "Project"}</strong>
            <span><Filter size={13} /> {knowledgeKindLabel(knowledgeItemKind)} · {knowledgeSearchTerm.trim() || "no query"} · {knowledgeItems.length}</span>
          </div>
          <div className="knowledge-list">
            {knowledgeItems.map((item) => (
              <article className="knowledge-row" key={item.knowledge_id}>
                <div className="knowledge-row-head">
                  <span className={`knowledge-kind ${item.item_kind}`}>{knowledgeKindLabel(item.item_kind)}</span>
                  <small>{formatShortDateTime(item.created_at)}</small>
                </div>
                <h3>{item.title}</h3>
                <p>{item.content}</p>
                {item.evidence_refs.length > 0 && (
                  <details className="knowledge-evidence">
                    <summary>근거 {item.evidence_refs.length}</summary>
                    <ul>
                      {item.evidence_refs.slice(0, 3).map((evidence, index) => (
                        <li key={`${evidence.segment_id ?? "evidence"}-${index}`}>
                          <strong>{formatEvidenceRef(evidence)}</strong>
                          {evidence.quote && <span>{evidence.quote}</span>}
                        </li>
                      ))}
                    </ul>
                  </details>
                )}
                <div className="knowledge-meta">
                  <span>{item.source_meeting_id ?? "meeting 없음"}</span>
                  <span>evidence {item.evidence_refs.length}</span>
                  {item.tags.slice(0, 3).map((tag) => <span key={tag}>{tag}</span>)}
                </div>
              </article>
            ))}
            {!selectedProject && <p className="muted">프로젝트를 선택하세요.</p>}
            {selectedProject && knowledgeItems.length === 0 && <p className="muted">지식 항목이 없습니다.</p>}
          </div>
        </section>

        <section className="visual-card ai-card">
          <div className="section-title">
            <h2>회의 지능화</h2>
            <ShieldCheck size={18} />
          </div>
          <div className="ai-summary">
            <strong>{review?.meeting.title ?? "검토 대기 회의"}</strong>
            <p>{result?.summary ?? "회의록 검토 패키지를 불러오면 요약, 후보, 리스크가 이곳에 시각화됩니다."}</p>
          </div>
          <div className="mini-metrics">
            <span><b>{result?.action_items.length ?? 0}</b> Action</span>
            <span><b>{result?.decisions.length ?? 0}</b> Decision</span>
            <span><b>{result?.risks.length ?? 0}</b> Risk</span>
            <span><b>{totalReviewItems}</b> Total</span>
          </div>
        </section>

        <section className="visual-card resource-card">
          <div className="section-title">
            <h2>Resource Pool</h2>
            <span className="ops-actions">
              <button
                className="icon-button"
                title="미배정 자원 수요를 리스크 후보로 생성"
                aria-label="미배정 자원 수요를 리스크 후보로 생성"
                onClick={onRunUnassignedResourceDemandRiskPromotion}
              >
                <Network size={14} />
              </button>
              <button
                className="icon-button"
                title="자원 충돌을 리스크 후보로 생성"
                aria-label="자원 충돌을 리스크 후보로 생성"
                onClick={onRunResourceConflictRiskPromotion}
              >
                <AlertTriangle size={14} />
              </button>
              <Layers size={18} />
            </span>
          </div>
          <div className="resource-split">
            <div>
              <strong>{resourceProfiles.length}</strong>
              <span>Profiles</span>
            </div>
            <div>
              <strong>{availableResources}</strong>
              <span>Available</span>
            </div>
            <div>
              <strong>{blockedResources}</strong>
              <span>Blocked</span>
            </div>
          </div>
          <div className="resource-list">
            {resourceAvailability.slice(0, 4).map((resource) => (
              <div className="resource-chip" key={resource.resource_id}>
                <span className={resource.is_available ? "dot ok" : "dot warn"} />
                <b>{resource.resource_name}</b>
                <small>
                  {resource.blocking_calendar_block_id
                    ? "calendar block"
                    : resource.blocking_allocation_id
                      ? "allocated"
                      : resource.resource_type}
                </small>
              </div>
            ))}
            {resourceAvailability.length === 0 && <p className="muted">등록된 Resource Pool profile이 없습니다.</p>}
          </div>
        </section>

        <section className="visual-card cost-card">
          <div className="section-title">
            <h2>Cost Feedback</h2>
            <span className="ops-actions">
              <button
                className="icon-button"
                title="사용실적 초과를 리스크 후보로 생성"
                aria-label="사용실적 초과를 리스크 후보로 생성"
                onClick={onRunResourceUsageOverrunRiskPromotion}
              >
                <Network size={14} />
              </button>
              <button
                className="icon-button"
                title="비용 초과 후보를 리스크 후보로 생성"
                aria-label="비용 초과 후보를 리스크 후보로 생성"
                onClick={onRunCostRiskPromotion}
              >
                <AlertTriangle size={14} />
              </button>
              <BarChart3 size={18} />
            </span>
          </div>
          <div className="cost-metrics">
            <div>
              <strong>{dashboard?.resource_usage_entries ?? resourceUsage.length}</strong>
              <span>Usage Logs</span>
            </div>
            <div>
              <strong>{dashboard?.cost_candidates ?? costCandidates.length}</strong>
              <span>Cost Candidates</span>
            </div>
            <div>
              <strong>{formatCurrency(totalCandidateCost, candidateCurrency)}</strong>
              <span>Candidate Total</span>
            </div>
          </div>
          <div className="cost-list">
            {costCandidates.slice(0, 4).map((candidate) => (
              <div className="cost-row" key={candidate.cost_id}>
                <span className="dot ok" />
                <span className="cost-main">
                  <b>{candidate.description ?? candidate.cost_type}</b>
                  <small>{candidate.project_id} · {candidate.source_type}</small>
                </span>
                <span className="cost-amount">{formatCurrency(candidate.amount, candidate.currency)}</span>
                <span className="cost-actions">
                  <button
                    className="icon-button approve"
                    title="비용 후보 승인"
                    aria-label={`${candidate.description ?? candidate.cost_type} 비용 후보 승인`}
                    onClick={() => onReviewCostCandidate(candidate.cost_id, "approved")}
                  >
                    <Check size={14} />
                  </button>
                  <button
                    className="icon-button reject"
                    title="비용 후보 반려"
                    aria-label={`${candidate.description ?? candidate.cost_type} 비용 후보 반려`}
                    onClick={() => onReviewCostCandidate(candidate.cost_id, "rejected")}
                  >
                    <Ban size={14} />
                  </button>
                </span>
              </div>
            ))}
            {costCandidates.length === 0 && <p className="muted">검토 대기 비용 후보가 없습니다.</p>}
          </div>
        </section>

        <section className="visual-card project-card">
          <div className="section-title">
            <h2>Project Portfolio</h2>
            <Database size={18} />
          </div>
          <div className="project-bars">
            {projects.slice(0, 5).map((project, index) => (
              <div className="project-bar" key={project.project_id}>
                <span>{project.name}</span>
                <i style={{ width: `${Math.max(24, 92 - index * 12)}%` }} />
                <small>{project.status}</small>
              </div>
            ))}
            {projects.length === 0 && <p className="muted">프로젝트가 아직 없습니다.</p>}
          </div>
        </section>
      </section>
    </section>
  );
}

function VisualConsole(props: Parameters<typeof LegacyVisualConsole>[0]) {
  const {
    dashboard,
    projects,
    review,
    resourceProfiles,
    resourceAvailability,
    resourceUsage,
    costCandidates,
    distributionLogs,
    recentMeetings,
    operationQueue,
    selectedProject,
    selectedProjectDetail,
    knowledgeItems,
    knowledgeItemKind,
    knowledgeSearchTerm,
    canRunErpHandoff,
    canViewSensitiveStaffing,
    onKnowledgeProjectChange,
    onKnowledgeItemKindChange,
    onKnowledgeSearchTermChange,
    onRefreshKnowledge,
    onReviewCostCandidate,
    onRunOverdueRiskPromotion,
    onRunCostRiskPromotion,
    onRunResourceConflictRiskPromotion,
    onRunUnassignedResourceDemandRiskPromotion,
    onRunResourceUsageOverrunRiskPromotion,
    onRunEmailRetryDue,
    onRunErpHandoffSendDue,
    onOpenMeeting,
  } = props;
  const result = review?.result;
  const activeProject = projects.find((project) => project.project_id === selectedProject) ?? projects[0] ?? null;
  const activeProjectDetail = selectedProjectDetail?.project_id === selectedProject ? selectedProjectDetail : null;
  const projectTitle = activeProject?.name ?? "AI 회의 플랫폼 구축";
  const projectDescription = activeProjectDetail?.description ?? activeProject?.description ?? "";
  const projectMembers = activeProjectDetail?.members ?? [];
  const totalAllocationPercent = projectMembers.reduce((sum, member) => sum + member.allocation_percent, 0);
  const totalPlannedMm = projectMembers.reduce((sum, member) => sum + member.planned_mm, 0);
  const totalAllocatedCost = projectMembers.reduce((sum, member) => sum + (member.allocated_cost_krw ?? 0), 0);
  const completedMeetings = Math.max(0, (dashboard?.meetings ?? 0) - (dashboard?.pending_reviews ?? 0));
  const availableResources = resourceAvailability.filter((resource) => resource.is_available).length;
  const blockedResources = resourceAvailability.filter((resource) => !resource.is_available).length;
  const totalCandidateCost = costCandidates.reduce((sum, candidate) => sum + candidate.amount, 0);
  const candidateCurrency = costCandidates[0]?.currency ?? "KRW";
  const latestDistribution = distributionLogs[0];
  const emailQueue = operationQueue?.email_distributions;
  const erpQueue = operationQueue?.erp_handoffs;
  const totalReviewItems =
    (result?.action_items.length ?? 0) +
    (result?.decisions.length ?? 0) +
    (result?.risks.length ?? 0) +
    (result?.required_resources.length ?? 0);
  const kpiCards = [
    { label: "회의수", value: dashboard?.meetings ?? 0, sub: "전체 회의", icon: <Users size={21} />, tone: "blue" },
    { label: "미검토", value: dashboard?.pending_reviews ?? 0, sub: "검토 대기 중", icon: <FileCheck2 size={21} />, tone: "amber" },
    { label: "승인대기", value: Math.max(dashboard?.pending_reviews ?? 0, totalReviewItems), sub: "승인 후보", icon: <UserPlus size={21} />, tone: "violet" },
    { label: "완료", value: completedMeetings, sub: "완료된 회의", icon: <Check size={21} />, tone: "green" },
  ];
  const designTabs = ["개요", "회의록", "업무", "문서", "리포트", "설정"];
  const navItems = [
    { label: "프로젝트", icon: <Folder size={18} />, active: true },
    { label: "업무보드", icon: <SquareKanban size={18} /> },
    { label: "회의록", icon: <FileCheck2 size={18} /> },
    { label: "문서함", icon: <FileText size={18} /> },
    { label: "대시보드", icon: <LayoutDashboard size={18} /> },
    { label: "보고서", icon: <BarChart3 size={18} /> },
  ];
  const projectRows = projects.slice(0, 4).map((project, index) => ({
    id: project.project_id,
    name: project.name,
    status: project.status,
    progress: Math.max(15, Math.min(100, project.status === "completed" ? 100 : 76 - index * 15)),
    tone: ["blue", "green", "violet", "slate"][index % 4],
  }));
  const projectQuickRows = projectRows.length > 0 ? projectRows : [
    { id: "sample-ai-meeting", name: "AI 회의 플랫폼 구축", status: "진행 중", progress: 75, tone: "blue" },
    { id: "sample-automation", name: "업무 자동화 시스템", status: "진행 중", progress: 45, tone: "green" },
    { id: "sample-docs", name: "프로젝트 문서공간", status: "완료", progress: 100, tone: "violet" },
  ];
  const noteListRows = recentMeetings.slice(0, 4).map((meeting, index) => ({
    id: meeting.meeting_id,
    title: meeting.title,
    project: meeting.project_name,
    time: formatShortDateTime(meeting.created_at),
    status: MEETING_STATUS_LABELS[meeting.status] ?? meeting.status,
    duration: ["42:18", "31:04", "58:22", "26:49"][index % 4],
  }));
  const displayedNoteRows = noteListRows.length > 0 ? noteListRows : [
    { id: "sample-note-1", title: "AI-PMS 주간 진행 회의", project: projectTitle, time: "오늘 10:30", status: "AI 요약 완료", duration: "42:18" },
    { id: "sample-note-2", title: "리스크·인력 배정 점검", project: projectTitle, time: "어제 16:10", status: "검토 대기", duration: "31:04" },
    { id: "sample-note-3", title: "Android 녹음 업로드 테스트", project: projectTitle, time: "06.28 14:20", status: "전사 완료", duration: "58:22" },
  ];
  const transcriptRows = [
    {
      segmentLabel: "구간 01",
      context: "Project_ID",
      time: "00:03",
      text: "오늘 회의는 Project_ID 기준으로 녹음, 전사, 분석, 승인, 배포까지 끊기지 않게 확인하겠습니다.",
      active: true,
    },
    {
      segmentLabel: "구간 02",
      context: "배포정책",
      time: "03:42",
      text: "참석자 선택은 제거하고 프로젝트 구성원 전체가 자동 배포 대상이 되도록 유지해야 합니다.",
      active: false,
    },
    {
      segmentLabel: "구간 03",
      context: "PMS연계",
      time: "12:08",
      text: "프로젝트 상세 API에 인력, 비용, 회의록 지식 항목이 같이 연결되어야 후속 업무 변환이 가능합니다.",
      active: false,
    },
    {
      segmentLabel: "구간 04",
      context: "앱화면",
      time: "24:31",
      text: "휴대폰은 녹음 중심, 태블릿은 스크립트와 요약을 동시에 보는 구조로 분기하겠습니다.",
      active: false,
    },
  ];
  const aiSummaryRows = [
    { label: "핵심 요약", text: "프로젝트 선택만으로 녹음과 분석 문맥을 고정하고, 승인 후 프로젝트 구성원에게 자동 배포한다." },
    { label: "결정사항", text: "회의 참석자 수동 선택은 제외하고 프로젝트 멤버십을 단일 배포 기준으로 사용한다." },
    { label: "후속업무", text: "Android 실기기 녹음 업로드와 Web 검토·승인 화면을 다음 확인 대상으로 둔다." },
  ];
  const noteModeRows = [
    { label: "요약", value: "3", icon: <Sparkles size={14} /> },
    { label: "스크립트", value: "42:18", icon: <FileText size={14} /> },
    { label: "검색", value: "키워드", icon: <Search size={14} /> },
    { label: "공유", value: "승인 후", icon: <Send size={14} /> },
  ];
  const annotationRows = [
    { label: "하이라이트", value: "4" },
    { label: "북마크", value: "2" },
    { label: "메모", value: "3" },
    { label: "AI Chat", value: "대기" },
  ];
  const aiCandidateRows = [
    { label: "Action", value: result?.action_items.length ?? 2, tone: "blue" },
    { label: "Risk", value: result?.risks.length ?? 1, tone: "amber" },
    { label: "Decision", value: result?.decisions.length ?? 2, tone: "green" },
  ];
  const boardColumns = [
    { label: "할 일", statuses: ["created", "upload_requested"], fallback: ["회의록 초안 생성", "요구사항 보완"] },
    { label: "진행 중", statuses: ["uploaded", "analysis_queued", "analyzing"], fallback: ["회의록 검토·승인", "프로젝트 문서 검토"] },
    { label: "검토", statuses: ["review_required"], fallback: ["회의록 최종 검토", "산출물 검토"] },
    { label: "완료", statuses: ["approved", "distributed"], fallback: ["주간 회의록 배포", "원본 음성 업로드"] },
  ].map((column) => {
    const rows = recentMeetings
      .filter((meeting) => column.statuses.includes(meeting.status))
      .slice(0, 5)
      .map((meeting) => ({
        id: meeting.meeting_id,
        title: meeting.title,
        meta: meeting.project_name,
        date: formatShortDateTime(meeting.created_at),
        tag: MEETING_STATUS_LABELS[meeting.status] ?? meeting.status,
        meetingId: meeting.meeting_id,
      }));
    return {
      ...column,
      rows: rows.length > 0 ? rows : column.fallback.map((title, index) => ({
        id: `${column.label}-${index}`,
        title,
        meta: projectTitle,
        date: index === 0 ? "D-1" : "D-3",
        tag: index === 0 ? "높음" : "보통",
        meetingId: "",
      })),
    };
  });
  const documentRows = [
    { id: "folder-minutes", icon: <Folder size={18} />, name: "회의록", type: "폴더", version: "-", date: `${dashboard?.meetings ?? 0}건`, owner: DEMO_COMPANY_NAME },
    { id: "folder-audio", icon: <Folder size={18} />, name: "원본 음성", type: "폴더", version: "-", date: `${recentMeetings.length}건`, owner: "Recorder" },
    { id: "folder-output", icon: <Folder size={18} />, name: "산출물", type: "폴더", version: "-", date: `${knowledgeItems.length}건`, owner: "AI 분석" },
    ...knowledgeItems.slice(0, 5).map((item) => ({
      id: item.knowledge_id,
      icon: <FileText size={18} />,
      name: item.title,
      type: knowledgeKindLabel(item.item_kind),
      version: "v1.0",
      date: formatShortDateTime(item.created_at),
      owner: item.status,
    })),
  ];
  const approvalRows = [
    ...(result?.decisions.slice(0, 3).map((decision, index) => ({
      id: `decision-${index}`,
      title: decision.content,
      status: "승인",
      date: review?.meeting.meeting_id ?? "meeting",
    })) ?? []),
    ...(result?.action_items.slice(0, 3).map((item, index) => ({
      id: `action-${index}`,
      title: item.title,
      status: item.priority === "high" ? "높음" : "보통",
      date: item.due_date ?? "미정",
    })) ?? []),
  ].slice(0, 5);
  const displayApprovalRows = approvalRows.length > 0 ? approvalRows : [
    { id: "fallback-ai", title: "AI 모델 학습 데이터셋 확정", status: "승인", date: "2026.07.01" },
    { id: "fallback-ui", title: "프로토타입 UI/UX 방향 확정", status: "승인", date: "2026.06.30" },
    { id: "fallback-security", title: "보안 요구사항 기준 수립", status: "승인", date: "2026.06.28" },
  ];
  const pipelineSteps = [
    { label: "업로드 완료", state: "done" },
    { label: "파일 검증", state: "done" },
    { label: "STT 처리", state: "active" },
    { label: "AI 구조화", state: "idle" },
    { label: "회의록 초안", state: "idle" },
  ];
  const attentionRows = [
    { label: "기한 임박 업무", value: dashboard?.overdue_tasks ?? 0, detail: "마감 기준" },
    { label: "오픈 리스크", value: dashboard?.unresolved_risks ?? 0, detail: "후보/진행" },
    { label: "자원 충돌", value: dashboard?.resource_conflicts ?? 0, detail: `${blockedResources} blocked` },
    { label: "배포 실패", value: dashboard?.distribution_failures ?? 0, detail: "재시도 대기" },
  ];

  return (
    <>
        <section className="workspace-head" data-screen-trace={SCREEN_DESIGN_TRACE_MARKERS.join(" | ")}>
          <div>
            <span className="breadcrumb">프로젝트</span>
            <h2>{projectTitle}</h2>
            {projectDescription && <p className="workspace-description">{projectDescription}</p>}
            <div className="workspace-tabs">
              {designTabs.map((tab, index) => (
                <button className={index === 0 ? "active" : ""} key={tab} type="button">{tab}</button>
              ))}
            </div>
          </div>
          <div className="workspace-actions">
            <button className="outline-action" type="button">
              <Settings size={16} /> 프로젝트 설정
            </button>
            <button type="button">
              <Plus size={16} /> 회의록 작성
            </button>
          </div>
        </section>

        <section className="workspace-kpis">
          {kpiCards.map((item) => (
            <article className={`workspace-kpi ${item.tone}`} key={item.label}>
              <span>{item.icon}</span>
              <div>
                <b>{item.value}</b>
                <small>{item.label}</small>
              </div>
              <em>{item.sub}</em>
            </article>
          ))}
        </section>

        <section className="workspace-layout">
          <article className="mf-panel mf-span-12 note-benchmark-workbench">
            <div className="note-rail">
              <div className="note-brand-chip">
                <Mic size={16} />
                <span>AI 회의록</span>
              </div>
              <button className="note-primary-action" type="button">
                <Plus size={16} /> 새 녹음
              </button>
              <nav className="note-rail-nav">
                <button className="active" type="button"><FileText size={15} /> 전체 노트</button>
                <button type="button"><Folder size={15} /> 프로젝트 노트</button>
                <button type="button"><Users size={15} /> 공유 받은 노트</button>
                <button type="button"><Search size={15} /> 키워드 검색</button>
              </nav>
              <div className="note-mode-grid">
                {noteModeRows.map((row) => (
                  <button key={row.label} type="button">
                    {row.icon}
                    <span>{row.label}</span>
                    <b>{row.value}</b>
                  </button>
                ))}
              </div>
              <div className="note-keyword-box">
                <span>자주 찾는 키워드</span>
                <b>Project_ID</b>
                <b>자동 배포</b>
                <b>리스크</b>
                <b>회의록 승인</b>
              </div>
            </div>

            <div className="note-list-pane">
              <div className="note-pane-head">
                <div>
                  <span>프로젝트 회의 노트</span>
                  <strong>{displayedNoteRows.length}개</strong>
                </div>
                <button className="icon-button" type="button" aria-label="회의록 새로고침">
                  <RefreshCw size={15} />
                </button>
              </div>
              <div className="note-search-box">
                <Search size={15} />
                <span>회의명, 안건, 키워드 검색</span>
              </div>
              <div className="note-list">
                {displayedNoteRows.map((note, index) => (
                  <button
                    className={`note-list-row ${index === 0 ? "active" : ""}`}
                    key={note.id}
                    type="button"
                    onClick={() => note.id.startsWith("sample") ? undefined : onOpenMeeting(note.id)}
                  >
                    <span>
                      <b>{note.title}</b>
                      <small>{note.project}</small>
                    </span>
                    <em>{note.status}</em>
                    <small>{note.time} · {note.duration}</small>
                  </button>
                ))}
              </div>
            </div>

            <div className="note-transcript-pane">
              <div className="note-detail-head">
                <div>
                  <span>{activeProject?.project_id ?? "SSK-SW-PJT-01"}</span>
                  <h3>{displayedNoteRows[0]?.title ?? "AI-PMS 주간 진행 회의"}</h3>
                  <p>{projectDescription || "프로젝트 회의 내용을 자동 전사하고 요약하여 프로젝트 구성원에게 배포합니다."}</p>
                </div>
                <div className="note-detail-actions">
                  <button className="outline-action" type="button"><Download size={15} /> 내보내기</button>
                  <button type="button"><Send size={15} /> 승인 배포</button>
                </div>
              </div>
              <div className="note-tabbar">
                <button className="active" type="button">스크립트</button>
                <button type="button">AI 요약</button>
                <button type="button">업무</button>
                <button type="button">키워드</button>
              </div>
              <div className="annotation-strip">
                {annotationRows.map((row) => (
                  <button key={row.label} type="button">
                    <span>{row.label}</span>
                    <b>{row.value}</b>
                  </button>
                ))}
              </div>
              <div className="transcript-list">
                {transcriptRows.map((row) => (
                  <div className={`transcript-row ${row.active ? "active" : ""}`} key={`${row.time}-${row.segmentLabel}`}>
                    <span className="segment-index">{row.segmentLabel.replace("구간 ", "")}</span>
                    <div>
                      <strong>{row.segmentLabel}<small>{row.context}</small></strong>
                      <p>{row.text}</p>
                    </div>
                    <time>{row.time}</time>
                  </div>
                ))}
              </div>
              <div className="note-player">
                <button type="button" aria-label="일시 정지"><PauseCircle size={22} /></button>
                <span>12:48</span>
                <div className="note-waveform" aria-hidden="true">
                  {Array.from({ length: 42 }, (_, index) => (
                    <i key={index} style={{ height: `${10 + (index % 9) * 3}px` }} />
                  ))}
                </div>
                <span>42:18</span>
              </div>
            </div>

            <aside className="note-ai-pane">
              <div className="ai-pane-title">
                <Sparkles size={17} />
                <strong>AI 메모</strong>
                <span>자동 생성</span>
              </div>
              <div className="ai-summary-list">
                {aiSummaryRows.map((row) => (
                  <section key={row.label}>
                    <b>{row.label}</b>
                    <p>{row.text}</p>
                  </section>
                ))}
              </div>
              <div className="ai-candidate-list">
                {aiCandidateRows.map((row) => (
                  <div className={`ai-candidate ${row.tone}`} key={row.label}>
                    <span>{row.label}</span>
                    <b>{row.value}</b>
                  </div>
                ))}
              </div>
              <div className="auto-distribution-box">
                <span>배포 대상</span>
                <strong>프로젝트 구성원 {projectMembers.length || 3}명</strong>
                <small>수동 참석자 선택 없음 · 이메일 기준 자동 발송</small>
              </div>
            </aside>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="최근 회의록" action="더보기" />
            <div className="compact-list">
              {recentMeetings.slice(0, 5).map((meeting) => (
                <button className="compact-row" key={meeting.meeting_id} type="button" onClick={() => onOpenMeeting(meeting.meeting_id)}>
                  <FileText size={16} />
                  <span>{meeting.title}</span>
                  <small>{formatShortDateTime(meeting.created_at)}</small>
                </button>
              ))}
              {recentMeetings.length === 0 && <p className="muted">최근 회의록이 없습니다.</p>}
            </div>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="최근 의사결정" action="더보기" />
            <div className="compact-list">
              {displayApprovalRows.map((row) => (
                <div className="compact-row decision" key={row.id}>
                  <span>{row.title}</span>
                  <i>{row.status}</i>
                  <small>{row.date}</small>
                </div>
              ))}
            </div>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="기한 임박 업무" action="더보기" />
            <div className="attention-list">
              {attentionRows.map((item) => (
                <div className="attention-row" key={item.label}>
                  <span className={`status-dot ${item.value > 0 ? "warn" : "done"}`} />
                  <span className="attention-main">
                    <b>{item.label}</b>
                    <small>{item.detail}</small>
                  </span>
                  <strong>{item.value}</strong>
                </div>
              ))}
            </div>
          </article>

          <article className="mf-panel mf-span-7">
            <PanelHeader title="업무보드" action="마감일 임박순" />
            <div className="kanban-board">
              {boardColumns.map((column) => (
                <div className="kanban-column" key={column.label}>
                  <div className="kanban-title">
                    <strong>{column.label}</strong>
                    <span>{column.rows.length}</span>
                    <MoreVertical size={15} />
                  </div>
                  {column.rows.map((row) => (
                    <button
                      className="kanban-card"
                      disabled={!row.meetingId}
                      key={row.id}
                      type="button"
                      onClick={() => row.meetingId && onOpenMeeting(row.meetingId)}
                    >
                      <b>{row.title}</b>
                      <small>{row.meta}</small>
                      <span>
                        <CalendarDays size={13} />
                        {row.date}
                        <i>{row.tag}</i>
                      </span>
                    </button>
                  ))}
                  <button className="board-add" type="button">
                    <Plus size={15} /> 업무 추가
                  </button>
                </div>
              ))}
            </div>
          </article>

          <article className="mf-panel mf-span-5">
            <PanelHeader title="프로젝트 상태" action="정상" />
            <div className="project-status">
              <div className="progress-ring">
                <strong>{projectQuickRows[0]?.progress ?? 75}%</strong>
                <span>전체 진행률</span>
              </div>
              <div className="project-bars">
                {projectQuickRows.map((project) => (
                  <div className="project-bar" key={project.id}>
                    <span>{project.name}</span>
                    <i className={project.tone} style={{ width: `${project.progress}%` }} />
                    <small>{project.status}</small>
                  </div>
                ))}
              </div>
            </div>
          </article>

          <article className="mf-panel mf-span-5 project-staffing-panel">
            <PanelHeader title="프로젝트 인력·투입" action={activeProjectDetail ? `${projectMembers.length}명` : "조회 중"} />
            <div className="staffing-summary">
              <div>
                <span>참여 인원</span>
                <strong>{projectMembers.length}</strong>
                <small>자동 배포 대상</small>
              </div>
              <div>
                <span>투입률</span>
                <strong>{formatPercent(totalAllocationPercent)}</strong>
                <small>프로젝트 합계</small>
              </div>
              <div>
                <span>계획 M/M</span>
                <strong>{formatMm(totalPlannedMm)}</strong>
                <small>월 기준</small>
              </div>
              <div>
                <span>배정원가</span>
                <strong>{formatCurrency(totalAllocatedCost, "KRW")}</strong>
                <small>연봉 기반 스냅샷</small>
              </div>
            </div>
            <div className="staffing-list">
              {projectMembers.map((member) => (
                <div className="staffing-row" key={member.user_id}>
                  <span className="staffing-person">
                    <UserRound size={17} />
                    <span>
                      <b>{member.name}</b>
                      <small>{member.employee_no} · {projectRoleLabel(member.project_role)} · {member.email ?? "이메일 미등록"}</small>
                    </span>
                  </span>
                  <span>
                    <b>{formatPercent(member.allocation_percent)}</b>
                    <small>투입률</small>
                  </span>
                  <span>
                    <b>{formatMm(member.planned_mm)}</b>
                    <small>계획 M/M</small>
                  </span>
                  <span>
                    <b>{formatCurrency(member.allocated_cost_krw ?? 0, "KRW")}</b>
                    <small>배정원가</small>
                  </span>
                  <span>
                    <b>{canViewSensitiveStaffing ? formatCurrency(member.annual_salary_krw ?? 0, "KRW") : "권한 제한"}</b>
                    <small>연봉 스냅샷</small>
                  </span>
                </div>
              ))}
              {projectMembers.length === 0 && (
                <p className="muted">프로젝트를 선택하면 참여 인원, 투입률, 계획 M/M, 배정원가를 표시합니다.</p>
              )}
            </div>
          </article>

          <article className="mf-panel mf-span-7">
            <PanelHeader title="프로젝트 문서공간" action="업로드" />
            <form
              className="document-toolbar"
              onSubmit={(event) => {
                event.preventDefault();
                onRefreshKnowledge();
              }}
            >
              <select value={selectedProject} onChange={(event) => onKnowledgeProjectChange(event.target.value)}>
                <option value="">프로젝트 선택</option>
                {projects.map((project) => (
                  <option key={project.project_id} value={project.project_id}>{project.name}</option>
                ))}
              </select>
              <select value={knowledgeItemKind} onChange={(event) => onKnowledgeItemKindChange(event.target.value as KnowledgeItemKind)}>
                {KNOWLEDGE_ITEM_KINDS.map((kind) => (
                  <option key={kind} value={kind}>{knowledgeKindLabel(kind)}</option>
                ))}
              </select>
              <div className="document-search">
                <Search size={15} />
                <input
                  value={knowledgeSearchTerm}
                  onChange={(event) => onKnowledgeSearchTermChange(event.target.value)}
                  placeholder="문서명 검색"
                />
              </div>
              <button className="secondary" disabled={!selectedProject} type="submit">
                <Search size={15} /> 조회
              </button>
            </form>
            <div className="document-table">
              <div className="document-head">
                <span>이름</span>
                <span>유형</span>
                <span>버전</span>
                <span>수정일</span>
                <span>수정자</span>
              </div>
              {documentRows.map((row) => (
                <div className="document-row" key={row.id}>
                  <span>{row.icon}<b>{row.name}</b></span>
                  <span>{row.type}</span>
                  <span>{row.version}</span>
                  <span>{row.date}</span>
                  <span>{row.owner}</span>
                </div>
              ))}
            </div>
          </article>

          <article className="mf-panel mf-span-5 phone-preview-panel">
            <PanelHeader title="앱 녹음·분석상태" action="APP-01~05" />
            <div className="phone-frame note-app-preview">
              <div className="phone-top">
                <span>9:41</span>
                <MoreVertical size={16} />
              </div>
              <div className="app-note-header">
                <strong>회의 녹음</strong>
                <button type="button" aria-label="검색"><Search size={16} /></button>
              </div>
              <section className="app-board-card active">
                <span>{projectTitle}</span>
                <b>{displayedNoteRows[0]?.title ?? "AI-PMS 주간 진행 회의"}</b>
                <small>프로젝트 기준 녹음 · 자동 배포</small>
              </section>
              <section className="app-recording-card">
                <div>
                  <span>녹음 중</span>
                  <strong>00:12:48</strong>
                </div>
                <div className="waveform" aria-hidden="true">
                  {Array.from({ length: 24 }, (_, index) => <i key={index} style={{ height: `${12 + (index % 7) * 5}px` }} />)}
                </div>
                <div className="app-record-controls">
                  <button type="button"><PauseCircle size={15} /> 일시 정지</button>
                  <button className="danger" type="button"><Square size={15} /> 녹음 종료</button>
                </div>
              </section>
              <div className="app-note-tabs">
                <button className="active" type="button">AI 요약</button>
                <button type="button">스크립트</button>
              </div>
              <section className="app-ai-card">
                <b>회의 요약</b>
                <p>프로젝트 구성원 자동 배포 정책을 유지하고, Android 실기기 녹음 업로드를 다음 확인 대상으로 둡니다.</p>
                <div>
                  <span>Action</span>
                  <small>API 계약 검증 · APK 설치 테스트</small>
                </div>
              </section>
              <div className="app-script-snippet">
                <span>구간 01 · 00:03</span>
                <p>Project_ID 기준으로 녹음과 분석 문맥을 고정합니다.</p>
              </div>
              <div className="phone-bottom-nav">
                <Home size={17} />
                <Folder size={17} />
                <Mic size={17} />
                <FileText size={17} />
                <Menu size={17} />
              </div>
            </div>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="회의록 검토·승인" action="WEB-04" />
            <div className="review-summary-card">
              <strong>{review?.meeting.title ?? "검토 대기 회의"}</strong>
              <p>{result?.summary ?? "회의록 검토 패키지를 불러오면 핵심 요약, 결정사항, 액션 아이템이 이곳에 표시됩니다."}</p>
              <div className="mini-metrics">
                <span><b>{result?.decisions.length ?? 0}</b> 결정</span>
                <span><b>{result?.action_items.length ?? 0}</b> 액션</span>
                <span><b>{result?.risks.length ?? 0}</b> 리스크</span>
                <span><b>{result?.required_resources.length ?? 0}</b> 자원</span>
              </div>
            </div>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="자원·비용" action="PMS 연계" />
            <div className="resource-split">
              <div><strong>{resourceProfiles.length}</strong><span>Profiles</span></div>
              <div><strong>{availableResources}</strong><span>Available</span></div>
              <div><strong>{blockedResources}</strong><span>Blocked</span></div>
            </div>
            <div className="cost-list">
              {costCandidates.slice(0, 2).map((candidate) => (
                <div className="cost-row" key={candidate.cost_id}>
                  <span className="dot ok" />
                  <span className="cost-main">
                    <b>{candidate.description ?? candidate.cost_type}</b>
                    <small>{formatCurrency(candidate.amount, candidate.currency)}</small>
                  </span>
                  <span className="cost-actions">
                    <button className="icon-button approve" type="button" onClick={() => onReviewCostCandidate(candidate.cost_id, "approved")} aria-label="비용 후보 승인">
                      <Check size={14} />
                    </button>
                    <button className="icon-button reject" type="button" onClick={() => onReviewCostCandidate(candidate.cost_id, "rejected")} aria-label="비용 후보 반려">
                      <Ban size={14} />
                    </button>
                  </span>
                </div>
              ))}
              {costCandidates.length === 0 && <p className="muted">검토 대기 비용 후보가 없습니다.</p>}
            </div>
          </article>

          <article className="mf-panel mf-span-4">
            <PanelHeader title="운영 자동화" action={latestDistribution?.status ?? "queue"} />
            <div className="ops-list">
              <div className="ops-row">
                <span className={`status-dot ${(emailQueue?.attention_count ?? 0) > 0 ? "warn" : "done"}`} />
                <span className="ops-main">
                  <b>Email Delivery</b>
                  <small>retry {emailQueue?.retry_due ?? 0} · failed {emailQueue?.status_counts.failed ?? 0}</small>
                </span>
                <button className="icon-button" type="button" onClick={onRunEmailRetryDue} aria-label="이메일 재시도">
                  <RefreshCw size={14} />
                </button>
              </div>
              <div className="ops-row">
                <span className={`status-dot ${(erpQueue?.attention_count ?? 0) > 0 ? "warn" : "done"}`} />
                <span className="ops-main">
                  <b>ERP Handoff</b>
                  <small>queued {erpQueue?.status_counts.queued ?? 0} · retry {erpQueue?.retry_due ?? 0}</small>
                </span>
                <button className="icon-button" disabled={!canRunErpHandoff} type="button" onClick={onRunErpHandoffSendDue} aria-label="ERP 송신">
                  <Send size={14} />
                </button>
              </div>
            </div>
            <div className="automation-actions">
              <button type="button" onClick={onRunOverdueRiskPromotion}><AlertTriangle size={14} /> 지연</button>
              <button type="button" onClick={onRunResourceConflictRiskPromotion}><Network size={14} /> 충돌</button>
              <button type="button" onClick={onRunUnassignedResourceDemandRiskPromotion}><UserPlus size={14} /> 미배정</button>
              <button type="button" onClick={onRunResourceUsageOverrunRiskPromotion}><Activity size={14} /> 초과</button>
              <button type="button" onClick={onRunCostRiskPromotion}><BarChart3 size={14} /> 비용</button>
            </div>
            <div className="cost-total">
              <span>후보 비용</span>
              <strong>{formatCurrency(totalCandidateCost, candidateCurrency)}</strong>
              <small>usage {resourceUsage.length} · sent {latestDistribution?.attempts.length ?? 0}</small>
            </div>
          </article>

          <article className="mf-panel mf-span-12 app-flow-showcase">
            <PanelHeader title="Android 앱 화면 흐름" action="APP-01~05" />
            <div className="app-screen-strip">
              <div className="mini-phone">
                <strong className="mini-logo">{PRODUCT_BRAND_NAME}</strong>
                <div className="mini-input">이메일 주소</div>
                <div className="mini-input">비밀번호</div>
                <button type="button">로그인</button>
                <h4>프로젝트 바로가기</h4>
                {projectQuickRows.slice(0, 3).map((project) => (
                  <div className="mini-project" key={project.id}>
                    <Folder size={15} />
                    <span>{project.name}</span>
                    <b>{project.progress}%</b>
                  </div>
                ))}
                <div className="mini-bottom"><Home size={15} /><Folder size={15} /><Mic size={15} /><FileText size={15} /><Menu size={15} /></div>
              </div>
              <div className="mini-phone">
                <h4>프로젝트 선택</h4>
                <div className="mini-step">1 프로젝트 선택</div>
                {projectQuickRows.slice(0, 3).map((project, index) => (
                  <div className={`mini-project ${index === 0 ? "selected" : ""}`} key={project.id}>
                    <Folder size={15} />
                    <span>{project.name}</span>
                    <b>{index === 0 ? <Check size={14} /> : `${project.progress}%`}</b>
                  </div>
                ))}
                <div className="mini-step">2 자동 배포 대상 확인</div>
                <div className="mini-avatars"><span>PM</span><span>PL</span><span>DEV</span><span>QA</span><em>ALL</em></div>
                <div className="mini-input">프로젝트 구성원 전체 자동 배포</div>
                <button type="button">회의 설정으로 이동</button>
              </div>
              <div className="mini-phone">
                <h4>회의 설정</h4>
                <div className="mini-form-row">회의 제목 <b>16/100</b></div>
                <div className="mini-form-row">프로젝트 <b>{projectTitle}</b></div>
                <div className="mini-form-grid"><span>2026.07.01</span><span>10:00</span></div>
                <div className="mini-segment"><b>정기 회의</b><span>임시 회의</span><span>외부 회의</span></div>
                <div className="mini-stats"><span>구성원 3명</span><span>프로젝트 15개</span><span>수동선택 없음</span></div>
                <div className="mini-textarea">새싹SW 프로젝트 진행 현황 공유 및 주요 이슈 논의</div>
                <button type="button">회의 시작</button>
              </div>
              <div className="mini-phone">
                <h4>회의 녹음</h4>
                <section className="mini-record">
                  <span>녹음 중</span>
                  <strong>00:12:48</strong>
                  <div className="waveform small" aria-hidden="true">
                    {Array.from({ length: 22 }, (_, index) => <i key={index} style={{ height: `${10 + (index % 6) * 4}px` }} />)}
                  </div>
                  <small>마이크 입력 중</small>
                </section>
                <div className="mini-actions"><button type="button">중요 구간</button><button type="button">일시 정지</button></div>
                <div className="mini-avatars"><span>PM</span><span>PL</span><span>DEV</span><span>QA</span><em>ALL</em></div>
                <div className="mini-upload">업로드 준비 완료 <b>12.4 MB</b></div>
                <button className="danger" type="button">녹음 종료</button>
              </div>
              <div className="mini-phone">
                <h4>업로드·분석상태</h4>
                <div className="mini-file"><FileText size={18} /><span>meeting_20260701.wav</span><b>업로드 완료</b></div>
                <div className="mini-process done">파일 검증 <b>완료</b></div>
                <div className="mini-process active">STT 처리 <b>65%</b></div>
                <div className="mini-process">AI 구조화 <b>대기</b></div>
                <div className="mini-process">회의록 초안 생성 <b>대기</b></div>
                <div className="mini-stepper">{pipelineSteps.map((step, index) => <span className={step.state} key={step.label}>{index + 1}</span>)}</div>
                <div className="mini-actions"><button type="button">프로젝트 홈</button><button type="button">상세 보기</button></div>
              </div>
            </div>
          </article>

          <article className="mf-panel mf-span-12 admin-showcase">
            <PanelHeader title="운영 관리자 대시보드" action="ADMIN-01" />
            <div className="admin-metric-strip">
              <div><span>회사 규모</span><strong>{DEMO_COMPANY_HEADCOUNT}명</strong><small>개발 {DEMO_COMPANY_DEVELOPER_COUNT}명</small></div>
              <div><span>연매출</span><strong>{DEMO_COMPANY_REVENUE_LABEL}</strong><small>SW 개발회사</small></div>
              <div><span>본부 구성</span><strong>{DEMO_COMPANY_DIVISION_COUNT}개</strong><small>{DEMO_COMPANY_DIVISIONS.join(" · ")}</small></div>
              <div><span>전체 프로젝트 수</span><strong>{dashboard?.projects ?? DEMO_COMPANY_PROJECT_COUNT}</strong><small>새싹SW 기준 15건</small></div>
              <div><span>분석 대기 작업</span><strong>{operationQueue?.email_distributions.retry_due ?? 0}</strong><small>회의 자동화 모듈</small></div>
              <div><span>배포 실패</span><strong className="danger">{dashboard?.distribution_failures ?? 0}</strong><small>프로젝트 구성원 자동 배포</small></div>
            </div>
            <div className="admin-grid">
              <div className="admin-donut"><strong>{DEMO_COMPANY_PROJECT_COUNT}</strong><span>새싹SW 프로젝트</span></div>
              <div className="worker-list">
                {["worker-01", "worker-02", "worker-03", "worker-04", "worker-05"].map((worker, index) => (
                  <div key={worker}><span>{worker}</span><i style={{ width: `${index === 4 ? 8 : 88 - index * 8}%` }} /><b>{index === 4 ? "오류" : "실행 중"}</b></div>
                ))}
              </div>
              <div className="admin-table">
                {["텍스트 추출 실패", "S3 업로드 실패", "파서 오류", "이메일 전송 실패"].map((error, index) => (
                  <div key={error}><span>10:{28 - index * 7}:14</span><b>{error}</b><small>{projectTitle}</small></div>
                ))}
              </div>
            </div>
          </article>
        </section>
    </>
  );
}

function PanelHeader({ title, action }: { title: string; action: string }) {
  return (
    <div className="panel-head">
      <h3>{title}</h3>
      <span>{action} <ChevronRight size={14} /></span>
    </div>
  );
}

function FlagIcon() {
  return <Square size={14} />;
}

function PublicDownloadPage() {
  const manifest = usePublicExecutionManifest();
  const apkInfo = manifest?.android_apk;
  const apkBuildFileName = apkInfo?.file_name ?? APK_FILE_NAME;
  const apkInstallFileName = apkInfo?.alias_file_name ?? apkBuildFileName;
  const apkDownloadUrl = manifest?.public_urls.apk_file ?? `${APK_DOWNLOAD_PATH}${apkInstallFileName}`;
  const runHubUrl = manifest?.public_urls.run_hub ?? RUN_PATH;
  const handoffUrl = manifest?.public_urls.handoff_page ?? HANDOFF_PATH;

  useEffect(() => {
    document.title = "AI-PMS Android APK";
  }, []);

  return (
    <main className="public-shell">
      <section className="public-hero">
        <div>
          <span className="eyebrow"><Download size={14} /> Android APK</span>
          <h1>AI-PMS Recorder APK</h1>
          <p>휴대폰과 태블릿 화면에 자동 대응하는 Android debug APK입니다.</p>
        </div>
        <div className="public-actions">
          <a className="public-button secondary" href={runHubUrl}>
            <Activity size={16} /> 실행 허브
          </a>
          <a className="public-button" href={apkDownloadUrl} download>
            <Download size={16} /> APK 다운로드
          </a>
          <a className="public-button secondary" href={handoffUrl}>
            <BookOpen size={16} /> 파트 전달안
          </a>
        </div>
      </section>

      <section className="public-card">
        <h2>APK 정보</h2>
        <dl className="public-dl">
          <dt>App</dt>
          <dd>{apkInfo?.app_name ?? "AI-PMS Recorder"}</dd>
          <dt>Package</dt>
          <dd><code>{apkInfo?.package_name ?? "com.aipms"}</code></dd>
          <dt>File</dt>
          <dd><code>{apkInstallFileName}</code></dd>
          <dt>Build file</dt>
          <dd><code>{apkBuildFileName}</code></dd>
          <dt>SHA256</dt>
          <dd><code>{apkInfo?.sha256 ?? APK_SHA256}</code></dd>
          <dt>Published</dt>
          <dd>{apkInfo?.published_at ?? APK_PUBLISHED_AT}</dd>
          <dt>Layout</dt>
          <dd>{apkInfo?.layout ?? "Phone single-column / Tablet two-column responsive layout"}</dd>
          <dt>Signing</dt>
          <dd>{apkInfo?.signing ?? "debug v2 signing"}. 장기 배포 전 release signing 필요</dd>
        </dl>
      </section>
    </main>
  );
}

function PublicHandoffPage() {
  const manifest = usePublicExecutionManifest();
  const urls = manifest?.public_urls;
  const runHubUrl = urls?.run_hub ?? RUN_PATH;
  const webConsoleUrl = urls?.web_console ?? PUBLIC_WEB_URL;
  const apkDownloadPageUrl = urls?.apk_download_page ?? APK_DOWNLOAD_PATH;
  const platformDocsUrl = urls?.platform_docs ?? `${PUBLIC_PLATFORM_URL}/docs`;
  const collectionDocsUrl = urls?.collection_docs ?? `${PUBLIC_COLLECTION_URL}/docs`;
  const analysisDocsUrl = urls?.analysis_docs ?? `${PUBLIC_ANALYSIS_URL}/docs`;

  useEffect(() => {
    document.title = "AI-PMS 파트별 확인 초안";
  }, []);

  return (
    <main className="public-shell">
      <section className="public-hero">
        <div>
          <span className="eyebrow"><BookOpen size={14} /> Team Handoff</span>
          <h1>AI-PMS 파트별 확인 초안</h1>
          <p>Project_ID 중심 PMS 흐름, 담당 파트별 검토 항목, 외부 접속 URL, Android APK 제공 정보를 한 화면에서 확인합니다.</p>
        </div>
        <div className="public-actions">
          <a className="public-button secondary" href={runHubUrl}>
            <Activity size={16} /> 실행 허브
          </a>
          <a className="public-button" href={apkDownloadPageUrl}>
            <Download size={16} /> APK 다운로드
          </a>
          <a className="public-button secondary" href={webConsoleUrl}>
            <BarChart3 size={16} /> Web 콘솔
          </a>
        </div>
      </section>

      <section className="public-card warning">
        <h2>공유 기준</h2>
        <p>현재 URL은 Cloudflare quick tunnel 기반 임시 주소입니다. Mac mini 또는 터널 세션이 재시작되면 주소가 바뀔 수 있습니다.</p>
      </section>

      <section className="public-card">
        <h2>전체 처리 흐름</h2>
        <div className="public-flow">
          <span>Android<br />녹음/업로드</span>
          <span>Collection API<br />수집/job queue</span>
          <span>Mac mini Worker<br />STT/LLM 검증</span>
          <span>Platform API<br />검토/승인/PMS 반영</span>
          <span>React Web<br />시각화/배포/운영</span>
        </div>
      </section>

      <section className="public-card">
        <h2>외부 접속</h2>
        <div className="public-link-grid">
          <a href={runHubUrl}>실행 허브</a>
          <a href={webConsoleUrl}>Web 콘솔</a>
          <a href={apkDownloadPageUrl}>APK 다운로드</a>
          <a href={platformDocsUrl}>Platform API</a>
          <a href={collectionDocsUrl}>Collection API</a>
          <a href={analysisDocsUrl}>Analysis Server</a>
        </div>
      </section>

      <section className="public-grid">
        <article className="public-card">
          <span className="status-pill active">김강현</span>
          <h3>Collection API 확인</h3>
          <ul>
            <li>upload session, upload token, multipart upload 계약</li>
            <li>worker heartbeat, claim, lease, retry 상태 전이</li>
            <li>Platform callback signing, replay, backoff</li>
          </ul>
        </article>
        <article className="public-card">
          <span className="status-pill active">박주연</span>
          <h3>Platform API 확인</h3>
          <ul>
            <li>auth, admin, project, meeting, approval 권한 경계</li>
            <li>Project_ID 기준 task, decision, risk, resource, cost 연결</li>
            <li>Collection callback idempotency와 schema validation</li>
          </ul>
        </article>
        <article className="public-card">
          <span className="status-pill active">김희섭</span>
          <h3>Android/Web/통합 확인</h3>
          <ul>
            <li>실기기 login, recording, upload, job status E2E</li>
            <li>Web review, approval, distribution, operations UX</li>
            <li>Mac mini audio job claim, STT/LLM 완료 검증</li>
          </ul>
        </article>
      </section>

      <section className="public-card">
        <h2>리뷰 회신 형식</h2>
        <dl className="public-dl">
          <dt>담당 파트</dt>
          <dd>Collection API / Platform API / Android-Web-통합</dd>
          <dt>결론</dt>
          <dd>승인 가능 / 수정 필요 / 질문</dd>
          <dt>수정 필요</dt>
          <dd>API, 데이터, 예외 흐름, 테스트 누락을 구체적으로 작성</dd>
          <dt>추가 테스트</dt>
          <dd>실기기, callback retry, 승인/배포, 운영 복구 등 보완 검증 작성</dd>
        </dl>
      </section>
    </main>
  );
}

function PublicRunPage() {
  const manifest = usePublicExecutionManifest();
  const [apkMetadata, setApkMetadata] = useState<ApkMetadata | null>(null);

  useEffect(() => {
    document.title = "AI-PMS 실행 허브";
    fetch(`${APK_DOWNLOAD_PATH}android-apk.json`)
      .then((response) => response.ok ? response.json() : null)
      .then((metadata) => setApkMetadata(metadata))
      .catch(() => setApkMetadata(null));
  }, []);

  const fallbackExecutionCommands = [
    {
      label: "로컬 API 서버",
      name: "local_base_services",
      commands: [
        "bash scripts/run_postgres.sh",
        "bash scripts/run_collection_api.sh",
        "bash scripts/run_analysis_server.sh",
        "bash scripts/run_analysis_worker_loop.sh",
        "bash scripts/run_platform_backend.sh",
      ],
    },
    {
      label: "로컬 React Web",
      name: "local_web",
      commands: [
        "cd web_client",
        "VITE_API_BASE=http://127.0.0.1:8000 npm run dev -- --host 0.0.0.0 --port 3000",
      ],
    },
    {
      label: "외부 접속 공개",
      name: "public_access",
      commands: [
        "bash scripts/run_public_tunnels.sh",
        "AIPMS_REFRESH_BUILD_APK=1 bash scripts/refresh_public_handoff_bundle.sh",
      ],
    },
    {
      label: "Android APK",
      name: "android_apk",
      commands: [
        "bash scripts/build_android_public_debug.sh",
        "bash scripts/install_android_public_debug_apk.sh",
      ],
    },
  ];
  const fallbackChecks = [
    "Web console loads from the public URL.",
    "APK download URL returns a file larger than 1 MB.",
    "Phone-width Android device shows single-column layout.",
    "Tablet-width Android device shows two-column layout.",
    "Platform, Collection, and Analysis health endpoints return 200.",
  ];
  const urls = manifest?.public_urls;
  const apkInfo = manifest?.android_apk;
  const executionCommands = manifest?.execution_commands ?? fallbackExecutionCommands;
  const minimumChecks = manifest?.minimum_checks ?? fallbackChecks;
  const runHubJsonUrl = urls?.run_hub ? `${urls.run_hub}execution.json` : `${RUN_PATH}execution.json`;
  const apkBuildFileName = apkInfo?.file_name ?? apkMetadata?.apk ?? APK_FILE_NAME;
  const apkFileName = apkInfo?.alias_file_name ?? apkMetadata?.apk_alias ?? apkBuildFileName;
  const apkFileUrl = urls?.apk_file ?? `${APK_DOWNLOAD_PATH}${apkFileName}`;
  const apkSizeMb = apkInfo?.size_mb ?? apkMetadata?.size_mb;
  const webConsoleUrl = urls?.web_console ?? PUBLIC_WEB_URL;
  const apkDownloadPageUrl = urls?.apk_download_page ?? APK_DOWNLOAD_PATH;
  const apkInstallGuideUrl = urls?.apk_install_guide ?? `${APK_DOWNLOAD_PATH}install.html`;
  const handoffPageUrl = urls?.handoff_page ?? HANDOFF_PATH;
  const reviewPackageUrl = urls?.review_package_json ?? `${HANDOFF_PATH}public-review-package.json`;
  const platformDocsUrl = urls?.platform_docs ?? `${PUBLIC_PLATFORM_URL}/docs`;
  const collectionDocsUrl = urls?.collection_docs ?? `${PUBLIC_COLLECTION_URL}/docs`;
  const analysisDocsUrl = urls?.analysis_docs ?? `${PUBLIC_ANALYSIS_URL}/docs`;

  return (
    <main className="public-shell">
      <section className="public-hero">
        <div>
          <span className="eyebrow"><Activity size={14} /> Execution Hub</span>
          <h1>AI-PMS 실행 허브</h1>
          <p>웹 콘솔, Android APK, API 서버, 외부 공개 터널을 한 곳에서 실행하고 검증합니다.</p>
        </div>
        <div className="public-actions">
          <a className="public-button" href={webConsoleUrl}>
            <BarChart3 size={16} /> Web 콘솔
          </a>
          <a className="public-button" href={apkDownloadPageUrl}>
            <Download size={16} /> APK 다운로드
          </a>
          <a className="public-button secondary" href={handoffPageUrl}>
            <BookOpen size={16} /> 파트 전달안
          </a>
        </div>
      </section>

      <section className="public-card">
        <h2>전체 실행 흐름</h2>
        <div className="public-flow">
          <span>Web<br />시각화/검토</span>
          <span>Android<br />녹음/업로드</span>
          <span>Collection<br />수집/job</span>
          <span>Analysis<br />STT/LLM</span>
          <span>Platform<br />PMS 반영</span>
        </div>
      </section>

      <section className="public-card">
        <h2>바로 열기</h2>
        <div className="public-link-grid">
          <a href={webConsoleUrl}>Web 콘솔</a>
          <a href={apkDownloadPageUrl}>APK 다운로드</a>
          <a href={apkInstallGuideUrl}>APK 설치 가이드</a>
          <a href={platformDocsUrl}>Platform API</a>
          <a href={collectionDocsUrl}>Collection API</a>
          <a href={analysisDocsUrl}>Analysis Server</a>
          <a href={reviewPackageUrl}>검토 패키지 JSON</a>
          <a href={runHubJsonUrl}>실행 JSON</a>
        </div>
      </section>

      <section className="public-run-grid">
        {executionCommands.map((item) => (
          <article className="public-card public-command-card" key={item.name}>
            <span className="status-pill active">{item.label}</span>
            <h3>{item.name}</h3>
            <pre className="public-command"><code>{item.commands.join("\n")}</code></pre>
          </article>
        ))}
      </section>

      <section className="public-card">
        <h2>APK 정보</h2>
        <dl className="public-dl">
          <dt>App</dt>
          <dd>{apkInfo?.app_name ?? apkMetadata?.app_name ?? "AI-PMS Recorder"}</dd>
          <dt>Package</dt>
          <dd><code>{apkInfo?.package_name ?? apkMetadata?.package_name ?? "com.aipms"}</code></dd>
          <dt>File</dt>
          <dd><a href={apkFileUrl}>{apkFileName}</a></dd>
          <dt>Build file</dt>
          <dd><code>{apkBuildFileName}</code></dd>
          <dt>Size</dt>
          <dd>{apkSizeMb ? `${apkSizeMb} MB` : "metadata loading"}</dd>
          <dt>Layout</dt>
          <dd>{apkInfo?.layout ?? apkMetadata?.layout ?? "responsive_phone_tablet"}</dd>
          <dt>Signing</dt>
          <dd>{apkInfo?.signing ?? apkMetadata?.signing ?? "debug_v2"}</dd>
          <dt>Published</dt>
          <dd>{apkInfo?.published_at ?? apkMetadata?.published_at ?? APK_PUBLISHED_AT}</dd>
          <dt>SHA256</dt>
          <dd><code>{apkInfo?.sha256 ?? apkMetadata?.sha256 ?? APK_SHA256}</code></dd>
        </dl>
      </section>

      <section className="public-card">
        <h2>최소 확인</h2>
        <ol>
          {minimumChecks.map((check) => <li key={check}>{check}</li>)}
        </ol>
      </section>
    </main>
  );
}

function AuthPanel({
  authView,
  loginForm,
  passwordResetRequestForm,
  passwordResetConfirmForm,
  message,
  onAuthViewChange,
  onLoginFormChange,
  onPasswordResetRequestFormChange,
  onPasswordResetConfirmFormChange,
  onLogin,
  onRequestPasswordReset,
  onConfirmPasswordReset,
}: {
  authView: AuthView;
  loginForm: { employee_no: string; password: string };
  passwordResetRequestForm: PasswordResetRequestForm;
  passwordResetConfirmForm: PasswordResetConfirmForm;
  message: string;
  onAuthViewChange: (value: AuthView) => void;
  onLoginFormChange: (value: { employee_no: string; password: string }) => void;
  onPasswordResetRequestFormChange: (value: PasswordResetRequestForm) => void;
  onPasswordResetConfirmFormChange: (value: PasswordResetConfirmForm) => void;
  onLogin: () => void;
  onRequestPasswordReset: () => void;
  onConfirmPasswordReset: () => void;
}) {
  if (authView === "reset-request") {
    return (
      <main className="auth-shell">
        <form className="auth-panel" onSubmit={(event) => { event.preventDefault(); onRequestPasswordReset(); }}>
          <div className="auth-title">
            <KeyRound size={20} />
            <h1>비밀번호 찾기</h1>
          </div>
          <label>
            <span>사번</span>
            <input
              autoComplete="username"
              value={passwordResetRequestForm.employee_no}
              onChange={(event) => onPasswordResetRequestFormChange({ ...passwordResetRequestForm, employee_no: event.target.value })}
            />
          </label>
          <label>
            <span>등록 이메일</span>
            <input
              autoComplete="email"
              type="email"
              value={passwordResetRequestForm.email}
              onChange={(event) => onPasswordResetRequestFormChange({ ...passwordResetRequestForm, email: event.target.value })}
            />
          </label>
          <div className="auth-actions">
            <button type="submit">인증 요청</button>
            <button className="secondary" type="button" onClick={() => onAuthViewChange("login")}>로그인</button>
          </div>
          {message && <pre className="message auth-message">{message}</pre>}
        </form>
      </main>
    );
  }

  if (authView === "reset-confirm") {
    return (
      <main className="auth-shell">
        <form className="auth-panel" onSubmit={(event) => { event.preventDefault(); onConfirmPasswordReset(); }}>
          <div className="auth-title">
            <KeyRound size={20} />
            <h1>비밀번호 재설정</h1>
          </div>
          <label>
            <span>인증 토큰</span>
            <input
              value={passwordResetConfirmForm.token}
              onChange={(event) => onPasswordResetConfirmFormChange({ ...passwordResetConfirmForm, token: event.target.value })}
            />
          </label>
          <label>
            <span>새 비밀번호</span>
            <input
              autoComplete="new-password"
              type="password"
              value={passwordResetConfirmForm.new_password}
              onChange={(event) => onPasswordResetConfirmFormChange({ ...passwordResetConfirmForm, new_password: event.target.value })}
            />
          </label>
          <label>
            <span>새 비밀번호 확인</span>
            <input
              autoComplete="new-password"
              type="password"
              value={passwordResetConfirmForm.confirm_password}
              onChange={(event) => onPasswordResetConfirmFormChange({ ...passwordResetConfirmForm, confirm_password: event.target.value })}
            />
          </label>
          <div className="auth-actions">
            <button type="submit">재설정</button>
            <button className="secondary" type="button" onClick={() => onAuthViewChange("reset-request")}>다시 요청</button>
          </div>
          {message && <pre className="message auth-message">{message}</pre>}
        </form>
      </main>
    );
  }

  return (
    <main className="auth-shell">
      <form className="auth-panel" onSubmit={(event) => { event.preventDefault(); onLogin(); }}>
        <div className="auth-title">
          <Lock size={20} />
          <h1>AI-PMS</h1>
        </div>
        <label>
          <span>사번</span>
          <input
            autoComplete="username"
            value={loginForm.employee_no}
            onChange={(event) => onLoginFormChange({ ...loginForm, employee_no: event.target.value })}
          />
        </label>
        <label>
          <span>비밀번호</span>
          <input
            autoComplete="current-password"
            type="password"
            value={loginForm.password}
            onChange={(event) => onLoginFormChange({ ...loginForm, password: event.target.value })}
          />
        </label>
        <div className="auth-actions">
          <button type="submit">로그인</button>
          <button className="secondary" type="button" onClick={() => onAuthViewChange("reset-request")}>비밀번호 찾기</button>
        </div>
        {message && <pre className="message auth-message">{message}</pre>}
      </form>
    </main>
  );
}

function PasswordChangePanel({
  user,
  passwordForm,
  message,
  onPasswordFormChange,
  onChangePassword,
  onLogout,
}: {
  user: User;
  passwordForm: { current_password: string; new_password: string; confirm_password: string };
  message: string;
  onPasswordFormChange: (value: { current_password: string; new_password: string; confirm_password: string }) => void;
  onChangePassword: () => void;
  onLogout: () => void;
}) {
  return (
    <main className="auth-shell">
      <form className="auth-panel" onSubmit={(event) => { event.preventDefault(); onChangePassword(); }}>
        <div className="auth-title">
          <UserRound size={20} />
          <h1>{user.name}</h1>
        </div>
        <label>
          <span>현재 비밀번호</span>
          <input
            autoComplete="current-password"
            type="password"
            value={passwordForm.current_password}
            onChange={(event) => onPasswordFormChange({ ...passwordForm, current_password: event.target.value })}
          />
        </label>
        <label>
          <span>새 비밀번호</span>
          <input
            autoComplete="new-password"
            type="password"
            value={passwordForm.new_password}
            onChange={(event) => onPasswordFormChange({ ...passwordForm, new_password: event.target.value })}
          />
        </label>
        <label>
          <span>새 비밀번호 확인</span>
          <input
            autoComplete="new-password"
            type="password"
            value={passwordForm.confirm_password}
            onChange={(event) => onPasswordFormChange({ ...passwordForm, confirm_password: event.target.value })}
          />
        </label>
        <div className="auth-actions">
          <button type="submit">변경</button>
          <button className="secondary" type="button" onClick={onLogout}>로그아웃</button>
        </div>
        {message && <pre className="message auth-message">{message}</pre>}
      </form>
    </main>
  );
}

function AdminUsersPanel({
  users,
  selectedUser,
  selectedUserId,
  createForm,
  editForm,
  resetPassword,
  onSelectUser,
  onCreateFormChange,
  onEditFormChange,
  onResetPasswordChange,
  onCreate,
  onSave,
  onResetPassword,
  onRefresh,
}: {
  users: User[];
  selectedUser: User | null;
  selectedUserId: string;
  createForm: UserCreateForm;
  editForm: UserEditForm;
  resetPassword: string;
  onSelectUser: (value: string) => void;
  onCreateFormChange: (value: UserCreateForm) => void;
  onEditFormChange: (value: UserEditForm) => void;
  onResetPasswordChange: (value: string) => void;
  onCreate: () => void;
  onSave: () => void;
  onResetPassword: () => void;
  onRefresh: () => void;
}) {
  return (
    <section className="admin-workspace">
      <form className="admin-section admin-create" onSubmit={(event) => { event.preventDefault(); onCreate(); }}>
        <div className="section-title">
          <h2>사용자 등록</h2>
          <button type="submit">
            <Plus size={16} /> 등록
          </button>
        </div>
        <div className="admin-form-grid">
          <label>
            <span>사번</span>
            <input
              value={createForm.employee_no}
              onChange={(event) => onCreateFormChange({ ...createForm, employee_no: event.target.value })}
            />
          </label>
          <label>
            <span>이름</span>
            <input
              value={createForm.name}
              onChange={(event) => onCreateFormChange({ ...createForm, name: event.target.value })}
            />
          </label>
          <label>
            <span>이메일</span>
            <input
              type="email"
              value={createForm.email}
              onChange={(event) => onCreateFormChange({ ...createForm, email: event.target.value })}
            />
          </label>
          <label>
            <span>역할</span>
            <select
              value={createForm.role}
              onChange={(event) => onCreateFormChange({ ...createForm, role: event.target.value as UserRole })}
            >
              {USER_ROLES.map((role) => <option key={role} value={role}>{role}</option>)}
            </select>
          </label>
          <label>
            <span>초기 비밀번호</span>
            <input
              type="password"
              value={createForm.initial_password}
              onChange={(event) => onCreateFormChange({ ...createForm, initial_password: event.target.value })}
            />
          </label>
        </div>
      </form>

      <section className="admin-section admin-list">
        <div className="section-title">
          <h2>사용자 목록</h2>
          <button className="secondary" onClick={onRefresh}>
            <RefreshCw size={16} /> 갱신
          </button>
        </div>
        <div className="user-table-wrap">
          <table className="user-table">
            <thead>
              <tr>
                <th>사용자</th>
                <th>사번</th>
                <th>역할</th>
                <th>상태</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.user_id} className={user.user_id === selectedUserId ? "selected" : undefined}>
                  <td>
                    <button className="text-button" onClick={() => onSelectUser(user.user_id)}>
                      {user.name}
                    </button>
                  </td>
                  <td>{user.employee_no}</td>
                  <td>{user.role}</td>
                  <td><span className={`status-pill ${user.status}`}>{user.status}</span></td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td colSpan={4}>등록된 사용자가 없습니다.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="admin-section admin-detail">
        <div className="section-title">
          <h2>사용자 편집</h2>
          <button disabled={!selectedUser} onClick={onSave}>
            <Save size={16} /> 저장
          </button>
        </div>
        {selectedUser ? (
          <>
            <div className="selected-user-head">
              <strong>{selectedUser.employee_no}</strong>
              <span>{selectedUser.user_id}</span>
            </div>
            <div className="admin-form-grid two-col">
              <label>
                <span>이름</span>
                <input
                  value={editForm.name}
                  onChange={(event) => onEditFormChange({ ...editForm, name: event.target.value })}
                />
              </label>
              <label>
                <span>이메일</span>
                <input
                  type="email"
                  value={editForm.email}
                  onChange={(event) => onEditFormChange({ ...editForm, email: event.target.value })}
                />
              </label>
              <label>
                <span>역할</span>
                <select
                  value={editForm.role}
                  onChange={(event) => onEditFormChange({ ...editForm, role: event.target.value as UserRole })}
                >
                  {USER_ROLES.map((role) => <option key={role} value={role}>{role}</option>)}
                </select>
              </label>
              <label>
                <span>상태</span>
                <select
                  value={editForm.status}
                  onChange={(event) => onEditFormChange({ ...editForm, status: event.target.value as UserStatus })}
                >
                  {USER_STATUSES.map((status) => <option key={status} value={status}>{status}</option>)}
                </select>
              </label>
            </div>
            <div className="reset-strip">
              <label>
                <span>초기화 비밀번호</span>
                <input
                  type="password"
                  value={resetPassword}
                  onChange={(event) => onResetPasswordChange(event.target.value)}
                />
              </label>
              <button className="secondary" onClick={onResetPassword}>
                <KeyRound size={16} /> 초기화
              </button>
            </div>
          </>
        ) : (
          <div className="empty">사용자를 선택하세요.</div>
        )}
      </section>
    </section>
  );
}

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: number }) {
  return (
    <div className="metric">
      {icon}
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ReviewPanel({
  review,
  draft,
  editReason,
  onDraftChange,
  onEditReasonChange,
}: {
  review: ReviewPackage;
  draft: MeetingAnalysisResult;
  editReason: string;
  onDraftChange: (draft: MeetingAnalysisResult) => void;
  onEditReasonChange: (value: string) => void;
}) {
  const editable = review.capabilities.can_edit;
  const updateDraft = (patch: Partial<MeetingAnalysisResult>) => onDraftChange({ ...draft, ...patch });
  const updateActionItem = (index: number, patch: Partial<ActionItemCandidate>) =>
    updateDraft({
      action_items: draft.action_items.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...patch } : item,
      ),
    });
  const updateDecision = (index: number, patch: Partial<DecisionCandidate>) =>
    updateDraft({
      decisions: draft.decisions.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...patch } : item,
      ),
    });
  const updateRisk = (index: number, patch: Partial<RiskCandidate>) =>
    updateDraft({
      risks: draft.risks.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...patch } : item,
      ),
    });
  const updateResource = (index: number, patch: Partial<RequiredResourceCandidate>) =>
    updateDraft({
      required_resources: draft.required_resources.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...patch } : item,
      ),
    });

  return (
    <div className="review-grid">
      <section className="summary-band">
        <div className="section-title">
          <h2>{review.meeting.title}</h2>
          <div className="badges">
            <span>{review.analysis_status}</span>
            <span>{review.model_name}</span>
            <span>{review.meeting.status}</span>
          </div>
        </div>
        <textarea
          disabled={!editable}
          value={draft.summary}
          onChange={(event) => updateDraft({ summary: event.target.value })}
          rows={4}
        />
        <input
          disabled={!editable}
          value={editReason}
          onChange={(event) => onEditReasonChange(event.target.value)}
          placeholder="변경 사유"
        />
      </section>

      <section>
        <h3>Action Items</h3>
        <div className="editor-list">
          {draft.action_items.map((item, index) => (
            <div className="editor-row action-row" key={index}>
              <input disabled={!editable} value={item.title} onChange={(event) => updateActionItem(index, { title: event.target.value })} />
              <input disabled={!editable} value={item.assignee ?? ""} placeholder="담당자" onChange={(event) => updateActionItem(index, { assignee: emptyToNull(event.target.value) })} />
              <input disabled={!editable} type="date" value={item.due_date ?? ""} onChange={(event) => updateActionItem(index, { due_date: event.target.value || null })} />
              <select disabled={!editable} value={item.priority} onChange={(event) => updateActionItem(index, { priority: event.target.value as ActionItemCandidate["priority"] })}>
                <option value="low">low</option>
                <option value="medium">medium</option>
                <option value="high">high</option>
              </select>
              <select disabled={!editable} value={item.task_conversion_status} onChange={(event) => updateActionItem(index, { task_conversion_status: event.target.value as ActionItemCandidate["task_conversion_status"] })}>
                <option value="candidate">candidate</option>
                <option value="rejected">rejected</option>
              </select>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h3>Decisions</h3>
        <div className="editor-list">
          {draft.decisions.map((item, index) => (
            <textarea disabled={!editable} key={index} value={item.content} onChange={(event) => updateDecision(index, { content: event.target.value })} rows={2} />
          ))}
        </div>
      </section>

      <section>
        <h3>Risks</h3>
        <div className="editor-list">
          {draft.risks.map((item, index) => (
            <div className="editor-row risk-row" key={index}>
              <input disabled={!editable} value={item.title} onChange={(event) => updateRisk(index, { title: event.target.value })} />
              <select disabled={!editable} value={item.level} onChange={(event) => updateRisk(index, { level: event.target.value as RiskCandidate["level"] })}>
                <option value="low">low</option>
                <option value="medium">medium</option>
                <option value="high">high</option>
              </select>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h3>Required Resources</h3>
        <div className="editor-list">
          {draft.required_resources.map((item, index) => (
            <div className="editor-row resource-row" key={index}>
              <input disabled={!editable} value={item.name} onChange={(event) => updateResource(index, { name: event.target.value })} />
              <select disabled={!editable} value={item.resource_type} onChange={(event) => updateResource(index, { resource_type: event.target.value as RequiredResourceCandidate["resource_type"] })}>
                <option value="human">human</option>
                <option value="equipment">equipment</option>
                <option value="room">room</option>
                <option value="vehicle">vehicle</option>
                <option value="software">software</option>
                <option value="other">other</option>
              </select>
              <input
                disabled={!editable}
                type="number"
                min="0"
                step="0.1"
                value={item.quantity ?? ""}
                onChange={(event) => updateResource(index, { quantity: event.target.value ? Number(event.target.value) : null })}
              />
            </div>
          ))}
        </div>
      </section>

      <section>
        <h3>Transcript</h3>
        <div className="transcript-list">
          {draft.transcript_segments.length === 0 ? (
            <p className="muted">없음</p>
          ) : draft.transcript_segments.map((item) => {
            const segmentLabel = formatEvidenceTime(item.start_ms) || item.segment_id;
            return <p key={item.segment_id}>{segmentLabel}: {item.text}</p>;
          })}
        </div>
      </section>
    </div>
  );
}

function DistributionPanel({
  preview,
  logs,
  onPreviewChange,
  onSend,
  onRefreshLogs,
}: {
  preview: EmailDistributionPreview;
  logs: EmailDistribution[];
  onPreviewChange: (preview: EmailDistributionPreview) => void;
  onSend: () => void;
  onRefreshLogs: () => void;
}) {
  return (
    <section className="distribution-panel">
      <div className="section-title">
        <div>
          <h2>회의록 배포</h2>
          <p className="muted">{preview.delivery_mode}</p>
        </div>
        <button disabled={!preview.can_distribute} onClick={onSend}>
          <Mail size={16} /> 발송
        </button>
      </div>
      <div className="distribution-form">
        <label>
          <span>제목</span>
          <input
            value={preview.subject}
            onChange={(event) => onPreviewChange({ ...preview, subject: event.target.value })}
          />
        </label>
        <label>
          <span>본문</span>
          <textarea
            rows={9}
            value={preview.body}
            onChange={(event) => onPreviewChange({ ...preview, body: event.target.value })}
          />
        </label>
      </div>
      <div className="recipient-head">
        <h3>프로젝트 구성원 자동 배포 대상</h3>
        <span className="muted">{preview.recipients.length}명</span>
      </div>
      <div className="recipient-list">
        {preview.recipients.map((recipient, index) => (
          <div className="recipient-row" key={index}>
            <span>{recipient.name ?? "-"}</span>
            <span>{recipient.email}</span>
            <span>{recipient.role ?? "member"}</span>
          </div>
        ))}
        {preview.recipients.length === 0 && (
          <p className="muted">이메일이 등록된 프로젝트 구성원이 없습니다.</p>
        )}
      </div>
      <div className="distribution-actions">
        <button className="secondary" onClick={onRefreshLogs}>
          <RefreshCw size={16} /> 이력 갱신
        </button>
      </div>
      <DistributionLogBlock logs={logs} />
    </section>
  );
}

function DistributionLogPanel({ logs }: { logs: EmailDistribution[] }) {
  return (
    <section className="distribution-panel">
      <div className="section-title">
        <h2>배포 이력</h2>
      </div>
      <DistributionLogBlock logs={logs} />
    </section>
  );
}

function DistributionLogBlock({ logs }: { logs: EmailDistribution[] }) {
  if (logs.length === 0) {
    return <p className="muted">기록 없음</p>;
  }

  return (
    <div className="delivery-list">
      {logs.map((log) => (
        <div className="delivery-row" key={log.distribution_id}>
          <div>
            <strong>{log.subject}</strong>
            <span>{log.distribution_id}</span>
          </div>
          <span className={`status-pill ${log.status}`}>{log.status}</span>
          <span>{log.delivery_mode}</span>
          <span>{log.attempts.length}명</span>
        </div>
      ))}
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <AppRouter
    app={<App />}
    downloads={<PublicDownloadPage />}
    handoff={<PublicHandoffPage />}
    run={<PublicRunPage />}
  />
);
