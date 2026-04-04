"use client";
import AppShell from "@/components/layout/AppShell";
import { useFetch } from "@/hooks/useFetch";
import Spinner from "@/components/ui/Spinner";
import Badge from "@/components/ui/Badge";
import {
  Users, FileText, Zap, TrendingUp,
  RefreshCw, AlertTriangle, Activity, DollarSign,
} from "lucide-react";
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer,
} from "recharts";

// ---------------------------------------------------------------------------
// KPI Card
// ---------------------------------------------------------------------------
function KpiCard({ label, value, sub, icon: Icon, accent }) {
  const accents = {
    blue:    "bg-blue-50   text-blue-600",
    emerald: "bg-emerald-50 text-emerald-600",
    amber:   "bg-amber-50   text-amber-600",
    red:     "bg-red-50     text-red-600",
    violet:  "bg-violet-50  text-violet-600",
  };
  return (
    <div className="bg-white rounded-2xl border border-slate-100 shadow-card p-5 flex items-start gap-4 hover:shadow-card-hover transition-shadow">
      <div className={`rounded-xl p-2.5 ${accents[accent] || accents.blue}`}>
        <Icon className="h-5 w-5" />
      </div>
      <div>
        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">{label}</p>
        <p className="text-2xl font-bold text-slate-900 mt-0.5">{value ?? "—"}</p>
        {sub && <p className="text-xs text-slate-400 mt-0.5">{sub}</p>}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Loss-ratio coloring
// ---------------------------------------------------------------------------
function lossRatioVariant(ratio) {
  if (ratio < 0.40) return "success";
  if (ratio < 0.65) return "warning";
  return "danger";
}

// ---------------------------------------------------------------------------
// Zone Table
// ---------------------------------------------------------------------------
function ZoneTable() {
  const { data, loading, error, refetch } = useFetch("/v1/admin/zones/stats");

  if (loading) return <div className="flex justify-center py-12"><Spinner /></div>;
  if (error)   return <p className="text-sm text-red-500 py-8 text-center">{error}</p>;

  const zones = data || [];

  return (
    <div className="bg-white rounded-2xl border border-slate-100 shadow-card overflow-hidden">
      <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
        <div>
          <h2 className="text-base font-semibold text-slate-900">Zone Performance</h2>
          <p className="text-xs text-slate-400 mt-0.5">{zones.length} active zones · last 7 days</p>
        </div>
        <button
          onClick={refetch}
          className="flex items-center gap-1.5 text-xs text-slate-500 hover:text-brand-600 transition"
        >
          <RefreshCw className="h-3.5 w-3.5" /> Refresh
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-slate-100 bg-slate-50/60">
              {["H3 Zone", "City", "Active Policies", "Claims (7d)",
                "Payout (7d)", "Loss Ratio", "Status"].map((h) => (
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
            {zones.map((z) => (
              <tr key={z.h3_index} className="hover:bg-slate-50/70 transition-colors">
                <td className="px-5 py-3.5 font-mono text-xs text-slate-500">{z.h3_index.slice(0, 12)}…</td>
                <td className="px-5 py-3.5 font-medium text-slate-800">{z.city}</td>
                <td className="px-5 py-3.5 text-slate-700">{z.active_policies.toLocaleString()}</td>
                <td className="px-5 py-3.5 text-slate-700">{z.total_claims_this_week.toLocaleString()}</td>
                <td className="px-5 py-3.5 text-slate-700">
                  ₹{Number(z.total_payout_this_week_inr).toLocaleString("en-IN")}
                </td>
                <td className="px-5 py-3.5">
                  <Badge
                    label={`${(z.loss_ratio * 100).toFixed(1)}%`}
                    variant={lossRatioVariant(z.loss_ratio)}
                  />
                </td>
                <td className="px-5 py-3.5">
                  <Badge
                    label={z.active_disruption ? "Disruption" : "Normal"}
                    variant={z.active_disruption ? "danger" : "success"}
                  />
                </td>
              </tr>
            ))}
            {zones.length === 0 && (
              <tr>
                <td colSpan={7} className="px-5 py-12 text-center text-sm text-slate-400">
                  No zone data available
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Dashboard Page
// ---------------------------------------------------------------------------
export default function DashboardPage() {
  const { data: health, loading, error, refetch } = useFetch("/v1/admin/system/health");

  const fmt = (n) => (n != null ? Number(n).toLocaleString("en-IN") : "—");
  const fmtInr = (n) => (n != null ? `₹${Number(n).toLocaleString("en-IN")}` : "—");
  const fmtPct = (n) => (n != null ? `${Number(n).toFixed(1)}%` : "—");

  // Build a mini sparkline from loss_ratio & automation_rate for the area chart
  const chartData = health
    ? [
        { name: "Revenue", value: Number(health.weekly_premium_revenue_inr) },
        { name: "Payouts",  value: Number(health.weekly_payout_total_inr)   },
      ]
    : [];

  return (
    <AppShell>
      {/* Page header */}
      <div className="flex items-center justify-between mb-7">
        <div>
          <h1 className="text-xl font-bold text-slate-900">Platform Overview</h1>
          <p className="text-sm text-slate-500 mt-0.5">Live metrics from EarnSure backend</p>
        </div>
        <button
          onClick={refetch}
          className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 hover:border-slate-300 transition shadow-sm"
        >
          <RefreshCw className="h-3.5 w-3.5" /> Refresh
        </button>
      </div>

      {loading && (
        <div className="flex justify-center py-16"><Spinner size="lg" /></div>
      )}
      {error && (
        <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-xl px-5 py-4 mb-6">
          <AlertTriangle className="h-4 w-4 text-red-500 shrink-0" />
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}

      {health && (
        <>
          {/* KPI Grid */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <KpiCard label="Active Policies"    value={fmt(health.total_active_policies)}  icon={FileText}   accent="blue"    sub="Currently live"           />
            <KpiCard label="Total Riders"       value={fmt(health.total_riders)}            icon={Users}      accent="violet"  sub="Registered accounts"     />
            <KpiCard label="Disruption Zones"   value={health.active_disruption_zones}     icon={AlertTriangle} accent="amber" sub="Zones with active events" />
            <KpiCard label="Automation Rate"    value={fmtPct(health.automation_rate_pct)} icon={Activity}   accent="emerald" sub="Auto-approved claims"    />
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
            <KpiCard label="Weekly Revenue"   value={fmtInr(health.weekly_premium_revenue_inr)} icon={DollarSign}  accent="emerald" sub="Premiums collected"     />
            <KpiCard label="Weekly Payouts"   value={fmtInr(health.weekly_payout_total_inr)}    icon={TrendingUp}  accent="red"     sub="Disbursed to riders"   />
            <KpiCard label="Loss Ratio"       value={fmtPct(health.overall_loss_ratio * 100)}   icon={TrendingUp}  accent="amber"   sub="Target < 40%"          />
            <KpiCard label="Payouts Queued"   value={health.payouts_queued}                      icon={Zap}         accent="blue"    sub="Pending settlement"    />
          </div>

          {/* Revenue vs Payout chart */}
          <div className="bg-white rounded-2xl border border-slate-100 shadow-card p-6 mb-6">
            <h2 className="text-base font-semibold text-slate-900 mb-1">Weekly Financial Summary</h2>
            <p className="text-xs text-slate-400 mb-5">Premium revenue vs. total payout disbursement</p>
            <ResponsiveContainer width="100%" height={180}>
              <AreaChart data={chartData} margin={{ top: 4, right: 4, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#0c8ee0" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#0c8ee0" stopOpacity={0}    />
                  </linearGradient>
                  <linearGradient id="payGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#f43f5e" stopOpacity={0.12} />
                    <stop offset="95%" stopColor="#f43f5e" stopOpacity={0}    />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="name" tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false}
                  tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} />
                <Tooltip
                  contentStyle={{ borderRadius: "12px", border: "1px solid #e2e8f0", fontSize: "12px" }}
                  formatter={(v) => [`₹${Number(v).toLocaleString("en-IN")}`, ""]}
                />
                <Area type="monotone" dataKey="value" name="Revenue" stroke="#0c8ee0" strokeWidth={2} fill="url(#revGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </>
      )}

      {/* Zone table */}
      <ZoneTable />
    </AppShell>
  );
}