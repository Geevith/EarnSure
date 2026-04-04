"use client";
import { Bell, Menu, Search } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

export default function Header({ onMenuClick }) {
  const pathname = usePathname();
  const pathSegments = pathname.split('/').filter(Boolean);
  const pageName = pathSegments.length > 0
    ? pathSegments.map(s => s.charAt(0).toUpperCase() + s.slice(1)).join(' / ')
    : 'Dashboard';

  return (
    <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-4 sm:px-6 z-30 sticky top-0">
      <div className="flex items-center gap-4">
        <button 
          onClick={onMenuClick}
          className="md:hidden text-slate-500 hover:text-slate-700"
        >
          <Menu size={24} />
        </button>
        <h1 className="text-xl font-semibold text-slate-800">{pageName}</h1>
      </div>

      <div className="flex items-center gap-4 sm:gap-6">
        <div className="flex items-center gap-3">
          <div className="hidden sm:block text-right">
            <div className="text-sm font-medium text-slate-700">Admin User</div>
            <div className="text-xs text-slate-500">Superadmin</div>
          </div>
          <div className="w-9 h-9 rounded-full bg-slate-100 border border-slate-300 flex items-center justify-center font-bold text-brand-600">
            A
          </div>
          <Link href="/login" className="text-slate-400 hover:text-rose-600 transition-colors">
            <span className="sr-only">Log out</span>
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path><polyline points="16 17 21 12 16 7"></polyline><line x1="21" y1="12" x2="9" y2="12"></line></svg>
          </Link>
        </div>
      </div>
    </header>
  );
}
