// ─────────────────────────────────────────────
// AI-PMS Web Client — 인증 커스텀 훅
// App 컴포넌트에서 인증 관련 상태와 로직을 분리합니다.
// ─────────────────────────────────────────────

import { useEffect, useRef, useState } from "react";
import { authApi, registerUnauthorizedHandler } from "../api/client";
import type { AuthSession, AuthView, User } from "../types";

const AUTH_STORAGE_KEY = "ai-pms-auth";

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

export function useAuth() {
  const [auth, setAuth] = useState<AuthSession | null>(() => readStoredAuth());
  const [authChecked, setAuthChecked] = useState(false);
  const [passwordChangeRequired, setPasswordChangeRequired] = useState(false);
  const [authView, setAuthView] = useState<AuthView>("login");

  // ── 401 자동 세션 만료 처리 ──────────────────────────────────────────────
  // 앱 전역의 모든 api() 호출에서 401이 반환되면 자동으로 로그아웃 처리한다.
  // setAuth/setPasswordChangeRequired는 useState setter로 참조 안정성이 보장됨.
  const setAuthRef = useRef(setAuth);
  const setPcrRef = useRef(setPasswordChangeRequired);
  useEffect(() => {
    const unregister = registerUnauthorizedHandler(() => {
      clearStoredAuth();
      setAuthRef.current(null);
      setPcrRef.current(false);
    });
    return unregister;
  }, []); // 마운트 시 한 번만 등록

  // 앱 시작 시 저장된 토큰 검증
  useEffect(() => {
    const stored = readStoredAuth();
    if (!stored) {
      setAuthChecked(true);
      return;
    }
    authApi
      .me(stored.accessToken)
      .then((user: User) => {
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

  async function login(employeeNo: string, password: string) {
    const result = await authApi.login({ employee_no: employeeNo, password });
    const nextAuth: AuthSession = {
      accessToken: result.access_token,
      expiresAt: result.expires_at,
      user: result.user,
    };
    setAuth(nextAuth);
    writeStoredAuth(nextAuth);
    setPasswordChangeRequired(result.password_change_required);
  }

  async function logout() {
    if (auth) {
      await authApi.logout(auth.accessToken).catch(() => undefined);
    }
    clearStoredAuth();
    setAuth(null);
    setPasswordChangeRequired(false);
  }

  async function changePassword(currentPassword: string, newPassword: string) {
    if (!auth) throw new Error("로그인이 필요합니다.");
    const oldToken = auth.accessToken;
    await authApi.changePassword(
      {
        employee_no: auth.user.employee_no,
        current_password: currentPassword,
        new_password: newPassword,
      },
      oldToken,
    );
    // 기존 토큰 revoke (best-effort — 실패해도 재로그인 진행)
    await authApi.logout(oldToken).catch(() => undefined);
    // 비밀번호 변경 후 새 토큰으로 재로그인
    const result = await authApi.login({
      employee_no: auth.user.employee_no,
      password: newPassword,
    });
    const nextAuth: AuthSession = {
      accessToken: result.access_token,
      expiresAt: result.expires_at,
      user: result.user,
    };
    setAuth(nextAuth);
    writeStoredAuth(nextAuth);
    setPasswordChangeRequired(false);
  }

  async function requestPasswordReset(employeeNo: string, email: string) {
    return authApi.requestPasswordReset({ employee_no: employeeNo, email });
  }

  async function confirmPasswordReset(token: string, newPassword: string) {
    return authApi.confirmPasswordReset({ token, new_password: newPassword });
  }

  return {
    auth,
    authChecked,
    passwordChangeRequired,
    authView,
    setAuthView,
    login,
    logout,
    changePassword,
    requestPasswordReset,
    confirmPasswordReset,
  };
}
