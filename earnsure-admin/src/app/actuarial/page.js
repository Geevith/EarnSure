"use client";
import AppShell from "@/components/layout/AppShell";
import StatCard from "@/components/ui/StatCard";
import Badge from "@/components/ui/Badge";
import { Activity, ShieldAlert, TrendingUp, DollarSign, Database } from "lucide-react";

export default function ActuarialPage() {
  return (
    <AppShell>
      <div className="flex items-center justify-between mb-7">
        <div>
          <h1 className="text-xl font-bold text-slate-900">Risk & Actuarial Dashboard</h1>
          <p className="text-sm text-slate-500 mt-0.5">
            Parametric model inputs, zone risk distributions, and capital efficiency
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 mb-6 gap-6">
        <div className="bg-white rounded-2xl border border-rose-200 shadow-sm p-6 overflow-hidden relative">
          <div className="absolute top-0 right-0 w-32 h-32 bg-rose-50 rounded-bl-full -mr-16 -mt-16 z-0"></div>
          <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <ShieldAlert className="h-5 w-5 text-rose-500" />
                <h2 className="text-sm font-semibold text-rose-600 uppercase tracking-wide">Break-even Claims Ratio</h2>
              </div>
              <div className="flex items-end gap-3">
                <span className="text-5xl font-black text-slate-900">47.3%</span>
                <span className="text-sm font-medium text-rose-500 mb-2">Target: 65.0%</span>
              </div>
              <p className="text-sm text-slate-500 mt-2">Shortfall of 17.7 pts below target in Current Period.</p>
            </div>
            
            <div className="flex gap-4">
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-100 min-w-32">
                <p className="text-xs text-slate-500 uppercase tracking-wide font-medium mb-1">Loss Ratio</p>
                <p className="text-xl font-bold text-slate-800">0.73</p>
              </div>
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-100 min-w-32">
                <p className="text-xs text-slate-500 uppercase tracking-wide font-medium mb-1">Combined Ratio</p>
                <p className="text-xl font-bold text-slate-800">0.91</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="bg-amber-100 text-amber-600 p-2 rounded-lg"><Activity className="h-4 w-4" /></div>
            <h3 className="text-sm font-semibold text-slate-800">Stress Scenario: Monsoon Flood</h3>
            <Badge label="SIMULATED" variant="warning" className="ml-auto" />
          </div>
          <div className="space-y-4">
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <span className="text-sm text-slate-500">Affected Zones</span>
              <span className="text-sm font-semibold text-slate-700">847 H3 Hexagons</span>
            </div>
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <span className="text-sm text-slate-500">Estimated Payout</span>
              <span className="text-sm font-semibold text-rose-600">₹3,80,250</span>
            </div>
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <span className="text-sm text-slate-500">Solvency Ratio</span>
              <span className="text-sm font-semibold text-emerald-600">3.16x</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-slate-500">Capital Reserve</span>
              <span className="text-sm font-semibold text-slate-700">₹12,00,000</span>
            </div>
          </div>
        </div>

        <div className="bg-slate-900 rounded-2xl border border-slate-800 shadow-sm p-6 text-white relative overflow-hidden">
          <div className="absolute opacity-10 -right-6 -bottom-6">
            <Database className="h-48 w-48 text-white" />
          </div>
          <div className="relative z-10">
            <div className="flex items-center gap-3 mb-5">
              <div className="bg-brand-500/20 text-brand-400 p-2 rounded-lg"><TrendingUp className="h-4 w-4" /></div>
              <h3 className="text-sm font-semibold text-white">Premium Formula</h3>
            </div>
            
            <div className="bg-black/40 rounded-xl p-5 mb-5 border border-white/10 text-center font-mono space-y-2">
              <div className="text-xl font-bold tracking-widest text-brand-400">P = R × Z × H × (1-S)</div>
              <div className="text-xs text-white/40">= ₹115 × 0.82 × 1.05 × 0.85</div>
              <div className="text-lg font-semibold text-white mt-1 pt-2 border-t border-white/10">≈ ₹98.00 / week</div>
            </div>

            <ul className="text-sm space-y-3 text-slate-400">
              <li className="flex gap-3"><span className="text-brand-400 font-mono font-bold w-4">R</span> Base rate (calibrated)</li>
              <li className="flex gap-3"><span className="text-brand-400 font-mono font-bold w-4">Z</span> Zone risk multiplier (H3)</li>
              <li className="flex gap-3"><span className="text-brand-400 font-mono font-bold w-4">H</span> Historical claims factor</li>
              <li className="flex gap-3"><span className="text-brand-400 font-mono font-bold w-4">S</span> Streak discount</li>
            </ul>
          </div>
        </div>
      </div>
    </AppShell>
  );
}
