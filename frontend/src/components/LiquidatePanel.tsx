import { useState } from "react";
import { useAccount, useConfig, useWriteContract } from "wagmi";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import type { AppConfig } from "../lib/api";
import { api, formatHealthFactorDisplay, parseUnits } from "../lib/api";
import { engineAbi } from "../lib/abis";
import { ensureAllowance } from "../lib/contracts";

type Props = { config: AppConfig };

export function LiquidatePanel({ config }: Props) {
  const { address } = useAccount();
  const wagmiConfig = useConfig();
  const queryClient = useQueryClient();
  const { writeContractAsync } = useWriteContract();

  const [victim, setVictim] = useState("");
  const [tokenIdx, setTokenIdx] = useState(0);
  const [debtToCover, setDebtToCover] = useState("1000");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const token = config.collateralTokens[tokenIdx]?.address;

  const victimHealth = useQuery({
    queryKey: ["health", victim],
    queryFn: () => api.getHealth(victim),
    enabled: victim.startsWith("0x") && victim.length === 42,
  });

  const preview = useQuery({
    queryKey: ["liq-preview", victim, token, debtToCover],
    queryFn: () => api.getLiquidationPreview(victim, token!, parseUnits(debtToCover).toString()),
    enabled: !!token && victim.startsWith("0x") && victim.length === 42,
  });

  const liquidate = async () => {
    if (!address || !token) return;
    setLoading(true);
    setError(null);
    try {
      const amt = parseUnits(debtToCover);
      await ensureAllowance(wagmiConfig, writeContractAsync, config.usdk, address, config.engine, amt);
      await writeContractAsync({
        address: config.engine,
        abi: engineAbi,
        functionName: "liquidate",
        args: [victim as `0x${string}`, token, amt],
      });
      queryClient.invalidateQueries({ queryKey: ["position"] });
      queryClient.invalidateQueries({ queryKey: ["health"] });
    } catch (e) {
      setError(e instanceof Error ? e.message : "清算失败");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card space-y-4">
      <h3 className="text-sm font-semibold text-slate-300">清算</h3>

      <div>
        <label className="label">被清算地址</label>
        <input
          className="input font-mono"
          placeholder="0x..."
          value={victim}
          onChange={(e) => setVictim(e.target.value)}
        />
      </div>

      {victimHealth.data && (
        <div className="rounded-lg bg-slate-950/60 p-2 text-xs">
          <div>
            HF:{" "}
            {
              formatHealthFactorDisplay(
                victimHealth.data.healthFactorFormatted,
                victimHealth.data.healthFactor,
              ).label
            }
          </div>
          <div className={victimHealth.data.canLiquidate ? "text-red-400" : "text-emerald-400"}>
            {victimHealth.data.canLiquidate ? "可清算" : "健康账户不可清算"}
          </div>
        </div>
      )}

      <div>
        <label className="label">抵押品</label>
        <select className="input" value={tokenIdx} onChange={(e) => setTokenIdx(Number(e.target.value))}>
          {config.collateralTokens.map((t, i) => (
            <option key={t.address} value={i}>
              {t.symbol}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="label">清偿债务 (USDK)</label>
        <input className="input" value={debtToCover} onChange={(e) => setDebtToCover(e.target.value)} />
      </div>

      {preview.data && (
        <div className="rounded-lg bg-slate-950/60 p-2 text-xs text-slate-400">
          <div>最大单次: {(Number(preview.data.maxDebtToCover) / 1e18).toFixed(4)} USDK</div>
          <div>实际清偿: {(Number(preview.data.finalDebtToCover) / 1e18).toFixed(4)} USDK</div>
          <div>
            获得抵押品: {(Number(preview.data.collateralAmount) / 1e18).toFixed(4)}{" "}
            {config.collateralTokens[tokenIdx]?.symbol}
          </div>
        </div>
      )}

      <button
        className="btn"
        disabled={loading || !address || !victimHealth.data?.canLiquidate}
        onClick={liquidate}
      >
        执行清算
      </button>
      {error && <p className="text-sm text-red-400">{error}</p>}
    </div>
  );
}
