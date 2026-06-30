// ─────────────────────────────────────────────
// AI-PMS Web Client — API 레이어
// 모든 서버 통신은 이 파일의 api() 함수를 통해 이루어집니다.
// 새 엔드포인트를 추가할 때도 이 파일에 함수를 추가하세요.
// ─────────────────────────────────────────────

import type {
  Dashboard,
  DelayedTaskRiskPromotion,
  CostCandidateRiskPromotion,
  ResourceConflictRiskPromotion,
  UnassignedResourceDemandRiskPromotion,
  ResourceUsageOverrunRiskPromotion,
  EmailDistribution,
  EmailDistributionPreview,
  LoginResponse,
  MeetingStatusItem,
  OperationQueueStatus,
  PasswordResetConfirmResponse,
  PasswordResetRequestResponse,
  Project,
  ProjectCostCandidate,
  ProjectCostHandoff,
  ProjectDetail,
  ProjectKnowledgeItem,
  ResourceAvailability,
  ResourceProfile,
  ResourceUsage,
  ReviewPackage,
  User,
} from "../types";

// ── 환경 설정 ──────────────────────────────────
// VITE_API_BASE 환경변수로 오버라이드 가능. 기본값은 현재 호스트의 8000 포트.
export const API_BASE =
  import.meta.env.VITE_API_BASE ??
  `${window.location.protocol}//${window.location.hostname}:8000`;

// ── 핵심 fetch 래퍼 ────────────────────────────
/**
 * 공통 API 호출 함수.
 * - 401/403/4xx/5xx 모두 Error를 throw합니다.
 * - accessToken이 없으면 Authorization 헤더를 붙이지 않습니다.
 */
export async function api<T>(
  path: string,
  init?: RequestInit,
  accessToken?: string,
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;

  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: { ...headers, ...(init?.headers ?? {}) },
  });

  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return response.json() as Promise<T>;
}

// ── Auth ───────────────────────────────────────
export const authApi = {
  login: (body: { employee_no: string; password: string }) =>
    api<LoginResponse>("/users/login", { method: "POST", body: JSON.stringify(body) }),

  me: (token: string) =>
    api<User>("/users/me", undefined, token),

  logout: (token: string) =>
    api<{ status: string }>("/users/logout", { method: "POST" }, token),

  changePassword: (
    body: { employee_no: string; current_password: string; new_password: string },
    token: string,
  ) =>
    api<{ employee_no: string; status: string }>(
      "/users/password/change",
      { method: "POST", body: JSON.stringify(body) },
      token,
    ),

  requestPasswordReset: (body: { employee_no: string; email: string }) =>
    api<PasswordResetRequestResponse>("/users/password-reset/request", {
      method: "POST",
      body: JSON.stringify(body),
    }),

  confirmPasswordReset: (body: { token: string; new_password: string }) =>
    api<PasswordResetConfirmResponse>("/users/password-reset/confirm", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};

// ── Projects ───────────────────────────────────
export const projectsApi = {
  list: (token: string) =>
    api<Project[]>("/projects", undefined, token),

  detail: (projectId: string, token: string) =>
    api<ProjectDetail>(`/projects/${encodeURIComponent(projectId)}/detail`, undefined, token),

  knowledgeItems: (
    projectId: string,
    params: { item_kind?: string; q?: string; limit?: number },
    token: string,
  ) => {
    const qs = new URLSearchParams({ limit: String(params.limit ?? 20) });
    if (params.item_kind && params.item_kind !== "all") qs.set("item_kind", params.item_kind);
    if (params.q?.trim()) qs.set("q", params.q.trim());
    return api<ProjectKnowledgeItem[]>(
      `/projects/${projectId}/knowledge-items?${qs}`,
      undefined,
      token,
    );
  },
};

// ── Dashboard ──────────────────────────────────
export const dashboardApi = {
  summary: (token: string) =>
    api<Dashboard>("/dashboard/summary", undefined, token),
};

// ── Meetings ───────────────────────────────────
export const meetingsApi = {
  list: (limit: number, token: string) =>
    api<MeetingStatusItem[]>(`/meetings?limit=${limit}`, undefined, token),

  reviewPackage: (meetingId: string, token: string) =>
    api<ReviewPackage>(`/meetings/${meetingId}/review-package`, undefined, token),

  saveEdits: (
    analysisId: string,
    body: { result: unknown; edit_reason: string | null },
    token: string,
  ) =>
    api<ReviewPackage>(
      `/meetings/analyses/${analysisId}/review-edits`,
      { method: "PUT", body: JSON.stringify(body) },
      token,
    ),

  distributionPreview: (meetingId: string, token: string) =>
    api<EmailDistributionPreview>(`/meetings/${meetingId}/distribution-preview`, undefined, token),

  distributions: (meetingId: string, token: string) =>
    api<EmailDistribution[]>(`/meetings/${meetingId}/distributions`, undefined, token),

  distribute: (
    meetingId: string,
    body: { subject: string; body: string },
    token: string,
  ) =>
    api<EmailDistribution>(
      `/meetings/${meetingId}/distribute`,
      { method: "POST", body: JSON.stringify(body) },
      token,
    ),
};

// ── Approvals ──────────────────────────────────
export const approvalsApi = {
  approve: (analysisId: string, token: string) =>
    api(`/approvals/meeting-analyses/${analysisId}/approve`, { method: "POST" }, token),
};

// ── Resources ──────────────────────────────────
export const resourcesApi = {
  profiles: (token: string) =>
    api<ResourceProfile[]>("/resources/profiles?status=active", undefined, token),

  availability: (startsOn: string, endsOn: string, token: string) =>
    api<ResourceAvailability[]>(
      `/resources/profiles/availability?starts_on=${startsOn}&ends_on=${endsOn}`,
      undefined,
      token,
    ),

  usage: (token: string) =>
    api<ResourceUsage[]>("/resources/usage", undefined, token),

  costCandidates: (status: string, token: string) =>
    api<ProjectCostCandidate[]>(`/resources/cost-candidates?status=${status}`, undefined, token),

  reviewCostCandidate: (
    costId: string,
    body: { status: "approved" | "rejected"; review_note: string },
    token: string,
  ) =>
    api<ProjectCostCandidate>(
      `/resources/cost-candidates/${costId}/status`,
      { method: "PATCH", body: JSON.stringify(body) },
      token,
    ),

  sendDueErpHandoffs: (limit: number, token: string) =>
    api<ProjectCostHandoff[]>(
      "/resources/cost-handoffs/send-due",
      { method: "POST", body: JSON.stringify({ limit }) },
      token,
    ),

  overdueRisks: (token: string) =>
    api<DelayedTaskRiskPromotion>("/tasks/overdue-risks", { method: "POST" }, token),

  costOverrunRisks: (thresholdAmount: number, currency: string, token: string) =>
    api<CostCandidateRiskPromotion>(
      `/resources/cost-candidates/overrun-risks?threshold_amount=${thresholdAmount}&currency=${currency}`,
      { method: "POST" },
      token,
    ),

  conflictRisks: (token: string) =>
    api<ResourceConflictRiskPromotion>(
      "/resources/allocations/conflict-risks",
      { method: "POST" },
      token,
    ),

  unassignedDemandRisks: (dueWithinDays: number, token: string) =>
    api<UnassignedResourceDemandRiskPromotion>(
      `/resources/demands/unassigned-risks?due_within_days=${dueWithinDays}`,
      { method: "POST" },
      token,
    ),

  usageOverrunRisks: (thresholdRatio: number, token: string) =>
    api<ResourceUsageOverrunRiskPromotion>(
      `/resources/usage/overrun-risks?threshold_ratio=${thresholdRatio}`,
      { method: "POST" },
      token,
    ),
};

// ── Operations ─────────────────────────────────
export const operationsApi = {
  queueStatus: (token: string) =>
    api<OperationQueueStatus>("/operations/queue-status", undefined, token),

  retryDueEmails: (limit: number, token: string) =>
    api<EmailDistribution[]>(
      "/distributions/retry-due",
      { method: "POST", body: JSON.stringify({ limit }) },
      token,
    ),
};

// ── Admin ──────────────────────────────────────
export const adminApi = {
  listUsers: (token: string) =>
    api<User[]>("/admin/users", undefined, token),

  createUser: (
    body: { employee_no: string; name: string; email: string | null; role: string; initial_password: string },
    token: string,
  ) =>
    api<User>("/admin/users", { method: "POST", body: JSON.stringify(body) }, token),

  updateUser: (
    userId: string,
    body: { name: string; email: string | null; role: string; status: string },
    token: string,
  ) =>
    api<User>(`/admin/users/${userId}`, { method: "PUT", body: JSON.stringify(body) }, token),

  resetPassword: (
    userId: string,
    body: { new_password: string; force_password_change: boolean },
    token: string,
  ) =>
    api<{ user: User; password_change_required: boolean; revoked_tokens: number }>(
      `/admin/users/${userId}/reset-password`,
      { method: "POST", body: JSON.stringify(body) },
      token,
    ),
};
