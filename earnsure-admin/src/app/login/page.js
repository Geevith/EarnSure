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
    <div className="min-h-screen flex font-sans">
      {/* Left split - Brand Hero */}
      <div className="hidden lg:flex lg:w-1/2 bg-slate-900 border-r border-slate-800 flex-col p-12 justify-between relative overflow-hidden">
        {/* Abstract background graphics */}
        <div className="absolute top-[-10%] left-[-10%] w-[120%] h-[120%] bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-brand-900/40 via-slate-900/90 to-slate-900"></div>
        <div className="absolute top-20 right-20 w-80 h-80 bg-brand-600/20 rounded-full blur-3xl rounded-full"></div>
        
        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-10">
            <div className="w-10 h-10 rounded-lg bg-brand-500 flex items-center justify-center font-bold text-xl text-white shadow-lg">E</div>
            <span className="font-bold text-2xl tracking-wide text-white">EarnSure</span>
          </div>
          
          <div className="mt-24">
            <h1 className="text-4xl lg:text-5xl font-extrabold text-white leading-tight mb-6 tracking-tight">
              Smarter parametric<br/>insurance for gig<br/>fleets.
            </h1>
            <p className="text-lg text-slate-400 mb-8 max-w-md">
              The centralized administrative console. Manage riders, evaluate zone risks, and process automated disruption claims seamlessly.
            </p>
          </div>
        </div>

        <div className="relative z-10 flex items-center gap-4 text-sm text-slate-500 font-medium">
          <ShieldCheck className="h-5 w-5 text-emerald-500" />
          Secured & Encrypted
        </div>
      </div>

      {/* Right split - Auth Form */}
      <div className="flex-1 bg-white flex flex-col justify-center px-4 sm:px-12 lg:px-24">
        <div className="w-full max-w-md mx-auto">
          {/* Mobile Header (Hidden on Desktop) */}
          <div className="flex lg:hidden items-center gap-3 mb-12">
            <div className="w-10 h-10 rounded-lg bg-brand-500 flex items-center justify-center font-bold text-xl text-white shadow-lg">E</div>
            <span className="font-bold text-2xl tracking-wide text-slate-900">EarnSure Admin</span>
          </div>

          <div className="mb-10">
            <h2 className="text-3xl font-bold text-slate-900 mb-2">Welcome back</h2>
            <p className="text-sm text-slate-500">Sign in to the administrative console to continue.</p>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Error block */}
            {error && (
              <div className="flex items-start gap-3 bg-rose-50 border border-rose-200 rounded-xl px-4 py-3">
                <AlertCircle className="h-5 w-5 text-rose-500 shrink-0 mt-0.5" />
                <p className="text-sm text-rose-700">{error}</p>
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-2 uppercase tracking-wide">
                Email address
              </label>
              <input
                type="email"
                required
                autoComplete="email"
                value={form.email}
                onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
                className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 transition-all shadow-sm shadow-slate-100"
                placeholder="admin@earnsure.in"
              />
            </div>

            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide">
                  Password
                </label>
                <a href="#" className="text-xs font-medium text-brand-600 hover:text-brand-700">Forgot password?</a>
              </div>
              <div className="relative">
                <input
                  type={show ? "text" : "password"}
                  required
                  autoComplete="current-password"
                  value={form.password}
                  onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
                  className="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 pr-11 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 transition-all shadow-sm shadow-slate-100"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShow((s) => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-1"
                >
                  {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 rounded-xl bg-brand-600 hover:bg-brand-700 active:bg-brand-800 text-white text-sm font-semibold py-3 mt-4 transition-colors disabled:opacity-60 disabled:cursor-not-allowed shadow-md shadow-brand-500/20"
            >
              {loading ? <Spinner size="sm" /> : null}
              {loading ? "Signing in…" : "Sign in to Dashboard"}
            </button>
          </form>
          
          <p className="text-center text-xs text-slate-400 mt-12">
            © {new Date().getFullYear()} EarnSure Platform
          </p>
        </div>
      </div>
    </div>
  );
}