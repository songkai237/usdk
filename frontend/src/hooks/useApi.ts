import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";

export function useAppConfig() {
  return useQuery({
    queryKey: ["config"],
    queryFn: api.getConfig,
    staleTime: 60_000,
  });
}

export function usePosition(address?: string) {
  return useQuery({
    queryKey: ["position", address],
    queryFn: () => api.getPosition(address!),
    enabled: !!address,
    refetchInterval: 10_000,
  });
}

export function useHealth(address?: string) {
  return useQuery({
    queryKey: ["health", address],
    queryFn: () => api.getHealth(address!),
    enabled: !!address,
    refetchInterval: 10_000,
  });
}

export function usePrices() {
  return useQuery({
    queryKey: ["prices"],
    queryFn: api.getPrices,
    refetchInterval: 15_000,
  });
}
