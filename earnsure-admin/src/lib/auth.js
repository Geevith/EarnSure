/**
 * Auth utilities — login, logout, session read.
 * Token is stored in localStorage with a JSON admin profile alongside it.
 * For stricter security in production, migrate to HttpOnly cookies via
 * a Next.js /api/auth proxy route.
 */

import api from "./api";

export const TOKEN_KEY   = "earnsure_token";
export const ADMIN_KEY   = "earnsure_admin";

/**
 * Calls POST /api/v1/auth/login, persists token + admin profile.
 * Returns the full TokenResponse payload.
 */
export async function login(email, password) {
  const { data } = await api.post("/v1/auth/login", { email, password });
  if (typeof window !== "undefined") {
    localStorage.setItem(TOKEN_KEY, data.access_token);
    localStorage.setItem(ADMIN_KEY, JSON.stringify({
      id:            data.admin_id,
      email:         data.email,
      full_name:     data.full_name,
      is_superadmin: data.is_superadmin,
    }));
  }
  return data;
}

export function logout() {
  if (typeof window !== "undefined") {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ADMIN_KEY);
    window.location.href = "/login";
  }
}

export function getToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getAdmin() {
  if (typeof window === "undefined") return null;
  try {
    return JSON.parse(localStorage.getItem(ADMIN_KEY));
  } catch {
    return null;
  }
}

export function isAuthenticated() {
  return Boolean(getToken());
}