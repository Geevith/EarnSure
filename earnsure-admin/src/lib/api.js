/**
 * Axios instance pre-configured for the EarnSure FastAPI backend.
 * Automatically attaches Bearer token from localStorage on every request.
 * Redirects to /login on 401 responses.
 */

import axios from "axios";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

const api = axios.create({
  baseURL: `${API_BASE_URL}/api`,
  headers: { "Content-Type": "application/json" },
  timeout: 15000,
});

// ---------------------------------------------------------------------------
// Request interceptor — attach JWT
// ---------------------------------------------------------------------------
api.interceptors.request.use(
  (config) => {
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("earnsure_token");
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ---------------------------------------------------------------------------
// Response interceptor — handle 401 globally
// ---------------------------------------------------------------------------
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (
      typeof window !== "undefined" &&
      error.response?.status === 401 &&
      !window.location.pathname.includes("/login")
    ) {
      localStorage.removeItem("earnsure_token");
      localStorage.removeItem("earnsure_admin");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export default api;