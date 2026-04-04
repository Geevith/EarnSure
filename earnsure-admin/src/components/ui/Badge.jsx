import clsx from "clsx";

const variants = {
  success: "bg-emerald-100 text-emerald-700 ring-emerald-600/20",
  warning: "bg-amber-100 text-amber-700 ring-amber-600/20",
  danger:  "bg-rose-100 text-rose-700 ring-rose-600/20",
  info:    "bg-brand-100 text-brand-700 ring-brand-600/20",
  neutral: "bg-slate-100 text-slate-700 ring-slate-500/20",
};

export default function Badge({ label, variant = "neutral" }) {
  return (
    <span
      className={clsx(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
        variants[variant]
      )}
    >
      {label}
    </span>
  );
}