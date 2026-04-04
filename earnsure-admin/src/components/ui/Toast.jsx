"use client";
import { useEffect } from "react";
import { CheckCircle, XCircle, X } from "lucide-react";
import clsx from "clsx";

export default function Toast({ toasts = [], dismiss }) {
  return (
    <div className="fixed bottom-5 right-5 z-50 flex flex-col gap-2 w-80">
      {toasts?.map((t) => (
        <ToastItem key={t.id} toast={t} dismiss={dismiss} />
      ))}
    </div>
  );
}

function ToastItem({ toast, dismiss }) {
  useEffect(() => {
    const timer = setTimeout(() => dismiss(toast.id), 4000);
    return () => clearTimeout(timer);
  }, [toast.id, dismiss]);

  return (
    <div
      className={clsx(
        "flex items-start gap-3 rounded-xl border px-4 py-3 shadow-lg bg-white animate-in slide-in-from-bottom-2",
        toast.type === "success" ? "border-emerald-200" : "border-red-200"
      )}
    >
      {toast.type === "success" ? (
        <CheckCircle className="h-5 w-5 text-emerald-500 shrink-0 mt-0.5" />
      ) : (
        <XCircle className="h-5 w-5 text-red-500 shrink-0 mt-0.5" />
      )}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-slate-800">{toast.title}</p>
        {toast.message && (
          <p className="text-xs text-slate-500 mt-0.5 truncate">{toast.message}</p>
        )}
      </div>
      <button onClick={() => dismiss(toast.id)} className="text-slate-400 hover:text-slate-600">
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}