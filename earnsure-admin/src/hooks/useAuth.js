"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getAdmin, isAuthenticated } from "@/lib/auth";

export function useAuth() {
  const router   = useRouter();
  const [admin, setAdmin]     = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace("/login");
      return;
    }
    setAdmin(getAdmin());
    setLoading(false);
  }, [router]);

  return { admin, loading };
}