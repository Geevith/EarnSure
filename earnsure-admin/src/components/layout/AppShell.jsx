"use client";
import Sidebar from "./Sidebar";
import { useAuth } from "@/hooks/useAuth";
import Spinner from "@/components/ui/Spinner";

export default function AppShell({ children }) {
  const { admin, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-slate-50">
        <Spinner size="lg" />
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      <Sidebar admin={admin} />
      <main className="flex-1 overflow-y-auto">
        <div className="px-8 py-8 max-w-7xl mx-auto">{children}</div>
      </main>
    </div>
  );
}