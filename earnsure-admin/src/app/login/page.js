"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Eye, EyeOff, AlertCircle } from "lucide-react";
import { login } from "@/lib/auth";
import Spinner from "@/components/ui/Spinner";

export default function LoginPage() {
  const router = useRouter();
  const [form,     setForm]    = useState({ email: "", password: "" });
  const [show,     setShow]    = useState(false);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await login(form.email, form.password);
      router.replace("/dashboard");
    } catch (err) {
      // Safely parse the error response
      const detail = err.response?.data?.detail;
      
      if (typeof detail === "string") {
        // Handles standard FastAPI HTTP exceptions (e.g., "Incorrect username or password")
        setError(detail);
      } else if (Array.isArray(detail) && detail.length > 0) {
        // Handles Pydantic validation errors (array of objects)
        setError(detail[0].msg);
      } else {
        // Fallback for network errors or unexpected payloads
        setError("Login failed. Please check your credentials or try again.");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-brand-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Card */}
        <div className="bg-white rounded-2xl shadow-2xl shadow-black/20 p-8">
          {/* Header */}
          <div className="flex flex-col items-center mb-8">
            <div className="h-12 w-12 rounded-xl bg-brand-500 flex items-center justify-center mb-4 shadow-lg shadow-brand-500/30">
              <ShieldCheck className="h-6 w-6 text-white" />
            </div>
            <h1 className="text-xl font-bold text-slate-900">EarnSure Admin</h1>
            <p className="text-sm text-slate-500 mt-1">Sign in to your dashboard</p>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-red-50 border border-red-200 rounded-xl px-4 py-3 mb-5">
              <AlertCircle className="h-4 w-4 text-red-500 shrink-0 mt-0.5" />
              <p className="text-sm text-red-700">{error}</p>
            </div>
          )}

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                Email address
              </label>
              <input
                type="email"
                required
                autoComplete="email"
                value={form.email}
                onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition"
                placeholder="admin@earnsure.in"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                Password
              </label>
              <div className="relative">
                <input
                  type={show ? "text" : "password"}
                  required
                  autoComplete="current-password"
                  value={form.password}
                  onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
                  className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 pr-11 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShow((s) => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                >
                  {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 rounded-xl bg-brand-500 hover:bg-brand-600 active:bg-brand-700 text-white text-sm font-semibold py-2.5 mt-2 transition disabled:opacity-60 disabled:cursor-not-allowed shadow-sm shadow-brand-500/20"
            >
              {loading ? <Spinner size="sm" /> : null}
              {loading ? "Signing in…" : "Sign in"}
            </button>
          </form>
        </div>

        <p className="text-center text-xs text-slate-500 mt-6">
          EarnSure Platform · Corporate Admin Console
        </p>
      </div>
    </div>
  );
}