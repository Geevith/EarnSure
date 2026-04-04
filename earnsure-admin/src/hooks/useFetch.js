"use client";
import { useEffect, useState, useCallback } from "react";
import api from "@/lib/api";

/**
 * Generic data-fetching hook.
 * Usage: const { data, loading, error, refetch } = useFetch("/v1/admin/system/health");
 */
export function useFetch(url, deps = []) {
  const [data,    setData]    = useState(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState(null);

  const fetchData = useCallback(async () => {
    if (!url) return;
    setLoading(true);
    setError(null);
    try {
      const { data: result } = await api.get(url);
      setData(result);
    } catch (err) {
      setError(err.response?.data?.detail || err.message || "Request failed");
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [url, ...deps]);

  useEffect(() => { fetchData(); }, [fetchData]);

  return { data, loading, error, refetch: fetchData };
}