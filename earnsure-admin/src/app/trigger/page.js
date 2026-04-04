"use client";
import { useState } from "react";
import AppShell from "@/components/layout/AppShell";
import { useToast } from "@/hooks/useToast";
import Toast from "@/components/ui/Toast";
import Spinner from "@/components/ui/Spinner";
import api from "@/lib/api";
import { Zap, Info, CheckCircle } from "lucide-react";

const DISRUPTION_TYPES = [
  { value: "monsoon",          label: "🌧  Monsoon / Heavy Rain",     hint: "e.g. 27.4 mm/hr" },
  { value: "heatwave",         label: "🌡  Heatwave",                 hint: "e.g. 46.2 °C"    },
  { value: "traffic_gridlock", label: "🚦  Traffic Gridlock",         hint: "severity 0–1"    },
  { value: "platform_outage",  label: "⚠️  Platform Outage",          hint: "minutes elapsed"  },
  { value: "civic_barricade",  label: "🚧  Civic Barricade",          hint: "severity 0–1"    },
];

export default function TriggerPage() {
  const { toasts, toast, dismiss } = useToast();
  const [form, setForm] = useState({
    h3_index:              "",
    disruption_type:       "monsoon",
    trigger_value:         "",
    bypass_nlp_confirmation: false,
    admin_note:            "",
  });
  const [loading,  setLoading]  = useState(false);
  const [result,   setResult]   = useState(null);

  function update(k, v) {
    setForm((f) => ({ ...f, [k]: v }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setResult(null);
    try {
      const payload = {
        h3_index:               form.h3_index.trim(),
        disruption_type:        form.disruption_type,
        trigger_value:          parseFloat(form.trigger_value),
        bypass_nlp_confirmation: form.bypass_nlp_confirmation,
        admin_note:              form.admin_note.trim() || null,
      };
      const { data } = await api.post("/v1/admin/trigger/manual", payload);
      setResult(data);
      toast({
        type:    "success",
        title:   "Disruption event triggered",
        message: `${data.riders_queued_for_payout} riders queued · Event ${data.disruption_event_id.slice(0, 8)}…`,
      });
    } catch (err) {
      const detail = err.response?.data?.detail;
      toast({
        type:    "error",
        title:   "Trigger failed",
        message: Array.isArray(detail)
          ? detail.map((d) => d.msg).join(", ")
          : (detail || err.message),
      });
    } finally {
      setLoading(false);
    }
  }

  const selectedType = DISRUPTION_TYPES.find((t) => t.value === form.disruption_type);

  return (
    <AppShell>
      <Toast toasts={toasts} dismiss={dismiss} />

      <div className="mb-7">
        <h1 className="text-xl font-bold text-slate-900">Manual Disruption Trigger</h1>
        <p className="text-sm text-slate-500 mt-0.5">
          Fire a parametric event in any H3 zone — instantly queues payouts for all active riders.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Form */}
        <div className="lg:col-span-3 bg-white rounded-2xl border border-slate-100 shadow-card p-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="h-8 w-8 rounded-lg bg-amber-50 flex items-center justify-center">
              <Zap className="h-4 w-4 text-amber-600" />
            </div>
            <h2 className="text-base font-semibold text-slate-900">Trigger Parameters</h2>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* H3 Index */}
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                H3 Zone Index
              </label>
              <input
                required
                value={form.h3_index}
                onChange={(e) => update("h3_index", e.target.value)}
                placeholder="e.g. 882a1072b3fffff"
                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm font-mono text-slate-900 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition"
              />
              <p className="text-xs text-slate-400 mt-1.5">
                H3 resolution 8 index. Get it from the Zone Performance table on the Overview page.
              </p>
            </div>

            {/* Disruption Type */}
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                Disruption Type
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {DISRUPTION_TYPES.map((t) => (
                  <label
                    key={t.value}
                    className={`flex items-center gap-3 rounded-xl border px-4 py-3 cursor-pointer transition-all ${
                      form.disruption_type === t.value
                        ? "border-brand-400 bg-brand-50 text-brand-700"
                        : "border-slate-200 hover:border-slate-300 text-slate-700"
                    }`}
                  >
                    <input
                      type="radio"
                      name="disruption_type"
                      value={t.value}
                      checked={form.disruption_type === t.value}
                      onChange={() => update("disruption_type", t.value)}
                      className="hidden"
                    />
                    <div
                      className={`h-4 w-4 rounded-full border-2 flex items-center justify-center shrink-0 ${
                        form.disruption_type === t.value ? "border-brand-500" : "border-slate-300"
                      }`}
                    >
                      {form.disruption_type === t.value && (
                        <div className="h-2 w-2 rounded-full bg-brand-500" />
                      )}
                    </div>
                    <span className="text-sm">{t.label}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* Trigger Value */}
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                Trigger Value{" "}
                <span className="text-slate-400 normal-case font-normal">
                  ({selectedType?.hint})
                </span>
              </label>
              <input
                required
                type="number"
                step="0.01"
                value={form.trigger_value}
                onChange={(e) => update("trigger_value", e.target.value)}
                placeholder={form.disruption_type === "monsoon" ? "27.4" : "46.2"}
                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition"
              />
            </div>

            {/* Admin Note */}
            <div>
              <label className="block text-xs font-semibold text-slate-600 mb-1.5 uppercase tracking-wide">
                Admin Note <span className="text-slate-400 normal-case font-normal">(optional)</span>
              </label>
              <textarea
                rows={2}
                value={form.admin_note}
                onChange={(e) => update("admin_note", e.target.value)}
                placeholder="e.g. MVP demo trigger — Chennai monsoon hex"
                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 transition resize-none"
              />
            </div>

            {/* Bypass NLP */}
            <label className="flex items-start gap-3 cursor-pointer group">
              <div className="relative mt-0.5">
                <input
                  type="checkbox"
                  checked={form.bypass_nlp_confirmation}
                  onChange={(e) => update("bypass_nlp_confirmation", e.target.checked)}
                  className="sr-only peer"
                />
                <div className="h-5 w-9 rounded-full bg-slate-200 peer-checked:bg-brand-500 transition-colors" />
                <div className="absolute left-0.5 top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform peer-checked:translate-x-4" />
              </div>
              <div>
                <p className="text-sm font-medium text-slate-800">Bypass NLP Confirmation</p>
                <p className="text-xs text-slate-400 mt-0.5">
                  Skip the secondary key (NLP social sentinel) check. For sandbox / demo use only.
                </p>
              </div>
            </label>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 rounded-xl bg-brand-500 hover:bg-brand-600 active:bg-brand-700 text-white text-sm font-semibold py-2.5 transition disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
            >
              {loading ? <Spinner size="sm" /> : <Zap className="h-4 w-4" />}
              {loading ? "Triggering event…" : "Fire Disruption Event"}
            </button>
          </form>
        </div>

        {/* Info + Result panel */}
        <div className="lg:col-span-2 flex flex-col gap-4">
          {/* How it works */}
          <div className="bg-white rounded-2xl border border-slate-100 shadow-card p-5">
            <div className="flex items-center gap-2 mb-4">
              <Info className="h-4 w-4 text-brand-500" />
              <h3 className="text-sm font-semibold text-slate-800">How it works</h3>
            </div>
            <ol className="space-y-3">
              {[
                "Admin submits H3 zone + disruption parameters",
                "Backend creates a confirmed DisruptionEvent (bypassing oracle for sandbox)",
                "Celery broadcasts payout tasks to all active policy holders in the hex",
                "Edge-AI validates device physics per rider",
                "Razorpay issues instant UPI payouts to eligible riders",
              ].map((step, i) => (
                <li key={i} className="flex items-start gap-3">
                  <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-brand-50 text-brand-600 text-xs font-bold mt-0.5">
                    {i + 1}
                  </span>
                  <p className="text-xs text-slate-600 leading-relaxed">{step}</p>
                </li>
              ))}
            </ol>
          </div>

          {/* Result card */}
          {result && (
            <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-5">
              <div className="flex items-center gap-2 mb-4">
                <CheckCircle className="h-5 w-5 text-emerald-600" />
                <h3 className="text-sm font-semibold text-emerald-800">Event Triggered</h3>
              </div>
              <div className="space-y-2.5">
                {[
                  ["Event ID",       result.disruption_event_id.slice(0, 16) + "…"],
                  ["Zone",           result.h3_index],
                  ["Type",           result.disruption_type],
                  ["Status",         result.status],
                  ["Riders Queued",  result.riders_queued_for_payout],
                  ["Est. Payout",    `₹${Number(result.estimated_total_payout_inr).toLocaleString("en-IN")}`],
                ].map(([label, value]) => (
                  <div key={label} className="flex justify-between">
                    <span className="text-xs font-medium text-emerald-700">{label}</span>
                    <span className="text-xs text-emerald-900 font-mono">{value}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </AppShell>
  );
}