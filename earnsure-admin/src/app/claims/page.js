"use client";
import { useState, useCallback } from "react";
import AppShell from "@/components/layout/AppShell";
import { useFetch } from "@/hooks/useFetch";
import { useToast } from "@/hooks/useToast";
import Toast from "@/components/ui/Toast";
import Badge from "@/components/ui/Badge";
import Spinner from "@/components/ui/Spinner";
import api from "@/lib/api";
import {
  CheckCircle, XCircle, RefreshCw,
  AlertTriangle, ChevronDown, ChevronUp,
} from "lucide-react";

function claimStatusVariant(s) {
  const map = {
    pending:  "warning",
    flagged:  "danger",
    approved: "info",
    paid:     "success",
    rejected: "neutral",
  };
  return map[s] || "neutral";
}

function fraudVariant(level) {
  return { low: "success", medium: "warning", high: "danger" }[level] || "neutral";
}

// ---------------------------------------------------------------------------
// Row-level action with confirm/reject note input
// ---------------------------------------------------------------------------
function ClaimRow({ claim, onReviewed }) {
  const [open,    setOpen]    = useState(false);
  const [note,    setNote]    = useState("");
  const [loading, setLoading] = useState(null); // "approve" | "reject"
  const { toast, toasts, dismiss } = useToast();

  async function handleReview(approve) {
    setLoading(approve ? "approve" : "reject");
    try {
      await api.post(
        `/v1/admin/claims/${claim.id}/review`,
        null,
        { params: { approve, note: note || undefined } }
      );
      toast({
        type:    "success",
        title:   approve ? "Claim approved" : "Claim rejected",
        message: `Claim ${claim.id.slice(0, 8)}… processed`,
      });
      onReviewed(claim.id);
    } catch (err) {
      toast({
        type:    "error",
        title:   "Action failed",
        message: err.response?.data?.detail || err.message,
      });
    } finally {
      setLoading(null);
    }
  }

  return (
    <>
      <Toast toasts={toasts} dismiss={dismiss} />
      <tr
        className="hover:bg-slate-50/70 transition-colors cursor-pointer"
        onClick={() => setOpen((o) => !o)}
      >
        <td className="px-5 py-3.5 font-mono text-xs text-slate-500">{claim.id.slice(0, 10)}…</td>
        <td className="px-5 py-3.5 font-mono text-xs text-slate-500">{claim.rider_id.slice(0, 10)}…</td>
        <td className="px-5 py-3.5 text-slate-700">
          ₹{Number(claim.calculated_payout_inr).toLocaleString("en-IN")}
        </td>
        <td className="px-5 py-3.5">
          <Badge label={claim.status}        variant={claimStatusVariant(claim.status)} />
        </td>
        <td className="px-5 py-3.5">
          <Badge label={claim.fraud_risk_level} variant={fraudVariant(claim.fraud_risk_level)} />
        </td>
        <td className="px-5 py-3.5 text-xs text-slate-400">
          {new Date(claim.created_at).toLocaleString("en-IN", { dateStyle: "short", timeStyle: "short" })}
        </td>
        <td className="px-5 py-3.5 text-slate-400">
          {open ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
        </td>
      </tr>

      {open && (
        <tr className="bg-slate-50/80 border-b border-slate-100">
          <td colSpan={7} className="px-5 py-4">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
              <div>
                <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Claimed Duration</p>
                <p className="text-sm text-slate-800">{claim.claimed_duration_hours}h</p>
              </div>
              <div>
                <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Approved Payout</p>
                <p className="text-sm text-slate-800">
                  {claim.approved_payout_inr
                    ? `₹${Number(claim.approved_payout_inr).toLocaleString("en-IN")}`
                    : "—"}
                </p>
              </div>
              <div>
                <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Rejection Reason</p>
                <p className="text-sm text-slate-800">{claim.rejection_reason || "—"}</p>
              </div>
            </div>

            {/* Review actions (only for pending/flagged) */}
            {["pending", "flagged"].includes(claim.status) && (
              <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-end">
                <div className="flex-1">
                  <label className="text-xs font-semibold text-slate-500 uppercase mb-1.5 block">
                    Admin note (optional)
                  </label>
                  <input
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    placeholder="e.g. GPS mismatch confirmed by cell tower data"
                    className="w-full rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-800 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition"
                    onClick={(e) => e.stopPropagation()}
                  />
                </div>
                <div className="flex gap-2 shrink-0">
                  <button
                    onClick={(e) => { e.stopPropagation(); handleReview(true); }}
                    disabled={!!loading}
                    className="flex items-center gap-2 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 text-sm font-medium transition disabled:opacity-50 shadow-sm"
                  >
                    {loading === "approve" ? <Spinner size="sm" /> : <CheckCircle className="h-4 w-4" />}
                    Approve
                  </button>
                  <button
                    onClick={(e) => { e.stopPropagation(); handleReview(false); }}
                    disabled={!!loading}
                    className="flex items-center gap-2 rounded-xl bg-red-500 hover:bg-red-600 text-white px-4 py-2 text-sm font-medium transition disabled:opacity-50 shadow-sm"
                  >
                    {loading === "reject" ? <Spinner size="sm" /> : <XCircle className="h-4 w-4" />}
                    Reject
                  </button>
                </div>
              </div>
            )}
          </td>
        </tr>
      )}
    </>
  );
}

// ---------------------------------------------------------------------------
// Claims Page
// ---------------------------------------------------------------------------
export default function ClaimsPage() {
  const { data, loading, error, refetch } = useFetch("/v1/admin/claims/pending");
  const [dismissed, setDismissed] = useState(new Set());

  const handleReviewed = useCallback((id) => {
    setDismissed((prev) => new Set([...prev, id]));
  }, []);

  const claims = (data?.items || []).filter((c) => !dismissed.has(c.id));
  const total  = data?.total ?? 0;

  return (
    <AppShell>
      <div className="flex items-center justify-between mb-7">
        <div>
          <h1 className="text-xl font-bold text-slate-900">Claims Management</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            Pending & flagged claims requiring review
          </p>
        </div>
        <button
          onClick={refetch}
          className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 hover:border-slate-300 transition shadow-sm"
        >
          <RefreshCw className="h-3.5 w-3.5" /> Refresh
        </button>
      </div>

      {/* Summary pill */}
      {!loading && (
        <div className="flex gap-3 mb-5">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium text-amber-700">
            <AlertTriangle className="h-3 w-3" />
            {total} claims awaiting review
          </span>
          {dismissed.size > 0 && (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-700">
              <CheckCircle className="h-3 w-3" />
              {dismissed.size} processed this session
            </span>
          )}
        </div>
      )}

      <div className="bg-white rounded-2xl border border-slate-100 shadow-card overflow-hidden">
        {loading && (
          <div className="flex justify-center py-16"><Spinner /></div>
        )}
        {error && (
          <div className="px-6 py-8 text-center text-sm text-red-500">{error}</div>
        )}

        {!loading && !error && (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/60">
                  {["Claim ID", "Rider ID", "Payout", "Status", "Fraud Risk", "Created", ""].map((h) => (
                    <th
                      key={h}
                      className="px-5 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wide whitespace-nowrap"
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {claims.map((c) => (
                  <ClaimRow key={c.id} claim={c} onReviewed={handleReviewed} />
                ))}
                {claims.length === 0 && (
                  <tr>
                    <td colSpan={7} className="px-5 py-14 text-center">
                      <CheckCircle className="h-8 w-8 text-emerald-300 mx-auto mb-3" />
                      <p className="text-sm font-medium text-slate-500">All caught up — no pending claims</p>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
            <Toast message="Action successful!" />
          </div>
        )}
      </div>
    </AppShell>
  );
}