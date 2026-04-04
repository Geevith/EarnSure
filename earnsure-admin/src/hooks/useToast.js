"use client";
import { useState, useCallback } from "react";

export function useToast() {
  const [toasts, setToasts] = useState([]);

  const toast = useCallback(({ type = "success", title, message }) => {
    const id = Math.random().toString(36).slice(2);
    setToasts((prev) => [...prev, { id, type, title, message }]);
  }, []);

  const dismiss = useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return { toasts, toast, dismiss };
}