const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8080";

export type AppConfig = {
  chainId: number;
  rpcUrl: string;
  usdk: `0x${string}`;
  engine: `0x${string}`;
  collateralTokens: {
    address: `0x${string}`;
    symbol: string;
    priceFeed: `0x${string}`;
  }[];
  priceFeeds: Record<string, `0x${string}`>;
};

export type Position = {
  address: string;
  debt: string;
  healthFactor: string;
  collateralUsd: string;
  maxSafeMint: string;
  usdkBalance: string;
  collateral: {
    token: string;
    symbol: string;
    deposited: string;
    walletBalance: string;
    usdPrice: string;
  }[];
};

export type Health = {
  healthFactor: string;
  healthFactorFormatted: string;
  canLiquidate: boolean;
  minHealthFactor: string;
};

export type LiquidationPreview = {
  maxDebtToCover: string;
  finalDebtToCover: string;
  collateralAmount: string;
  totalUsdWithBonus: string;
};

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? res.statusText);
  }
  return res.json();
}

export const api = {
  getConfig: () => get<AppConfig>("/api/config"),
  getPosition: (address: string) => get<Position>(`/api/position/${address}`),
  getHealth: (address: string) => get<Health>(`/api/position/${address}/health`),
  getPrices: () => get<{ weth: string; wbtc: string }>("/api/prices"),
  getLiquidationPreview: (account: string, token: string, debtToCover: string) =>
    get<LiquidationPreview>(
      `/api/liquidation/preview?account=${account}&token=${token}&debtToCover=${debtToCover}`,
    ),
};

export function formatUnits(value: string, decimals = 18, precision = 4): string {
  const v = BigInt(value);
  const base = 10n ** BigInt(decimals);
  const whole = v / base;
  const frac = v % base;
  const fracStr = frac.toString().padStart(decimals, "0").slice(0, precision);
  return `${whole}.${fracStr}`;
}

export function parseUnits(value: string, decimals = 18): bigint {
  const [whole, frac = ""] = value.split(".");
  const padded = frac.padEnd(decimals, "0").slice(0, decimals);
  return BigInt(whole + padded);
}

export function hfToNumber(hf: string): number {
  return Number(hf) / 1e18;
}

const MAX_UINT256 =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const VERY_HEALTHY_THRESHOLD = 100;

/** 无债务或 HF 极大时显示「非常健康」，避免 uint256.max 等超长数字 */
export function formatHealthFactorDisplay(
  hfFormatted: string,
  healthFactorRaw?: string,
): { label: string; hf: number; isVeryHealthy: boolean } {
  if (healthFactorRaw === MAX_UINT256) {
    return { label: "非常健康", hf: VERY_HEALTHY_THRESHOLD, isVeryHealthy: true };
  }

  const hf = parseFloat(hfFormatted);
  if (!Number.isFinite(hf) || hf >= VERY_HEALTHY_THRESHOLD) {
    return { label: "非常健康", hf: VERY_HEALTHY_THRESHOLD, isVeryHealthy: true };
  }

  return { label: hfFormatted, hf, isVeryHealthy: false };
}
