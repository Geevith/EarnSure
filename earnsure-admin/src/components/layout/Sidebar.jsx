"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  FileText,
  Zap,
  LogOut,
  ShieldCheck,
  ChevronRight,
} from "lucide-react";
import clsx from "clsx";
import { logout } from "@/lib/auth";

const NAV = [
  { href: "/dashboard",  label: "Overview",       icon: LayoutDashboard },
  { href: "/claims",     label: "Claims",          icon: FileText        },
  { href: "/trigger",    label: "Trigger Event",   icon: Zap             },
];

export default function Sidebar({ admin }) {
  const pathname = usePathname();

  return (
    <aside className="flex flex-col w-64 min-h-screen bg-slate-900 text-white shrink-0">
      {/* Logo */}
      <div className="flex items-center gap-2.5 px-6 py-5 border-b border-slate-800">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-500">
          <ShieldCheck className="h-4 w-4 text-white" />
        </div>
        <div>
          <p className="text-sm font-bold leading-none text-white">EarnSure</p>
          <p className="text-[10px] text-slate-400 mt-0.5">Admin Console</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-0.5">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={clsx(
                "group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all",
                active
                  ? "bg-brand-600 text-white shadow-sm"
                  : "text-slate-400 hover:bg-slate-800 hover:text-white"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {label}
              {active && (
                <ChevronRight className="ml-auto h-3.5 w-3.5 text-brand-200" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* Admin profile */}
      <div className="px-3 pb-4 border-t border-slate-800 pt-4">
        <div className="flex items-center gap-3 rounded-lg px-3 py-2.5 mb-1">
          <div className="h-8 w-8 rounded-full bg-brand-500 flex items-center justify-center shrink-0">
            <span className="text-xs font-bold text-white">
              {admin?.full_name?.[0] ?? admin?.email?.[0]?.toUpperCase() ?? "A"}
            </span>
          </div>
          <div className="min-w-0">
            <p className="text-sm font-medium text-white truncate">
              {admin?.full_name ?? "Admin"}
            </p>
            <p className="text-xs text-slate-400 truncate">{admin?.email}</p>
          </div>
        </div>
        <button
          onClick={logout}
          className="w-full flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-slate-400 hover:bg-slate-800 hover:text-white transition-all"
        >
          <LogOut className="h-4 w-4" />
          Sign out
        </button>
      </div>
    </aside>
  );
}