import { formatHealthFactorDisplay } from "../lib/api";

export function HealthGauge({
  hfFormatted,
  healthFactor,
  canLiquidate,
}: {
  hfFormatted: string;
  healthFactor?: string;
  canLiquidate: boolean;
}) {
  const { label, hf, isVeryHealthy } = formatHealthFactorDisplay(hfFormatted, healthFactor);
  const pct = Math.min(Math.max(hf / 2, 0), 1) * 100;
  const color = canLiquidate ? "bg-red-500" : "bg-emerald-500";

  return (
    <div className="card">
      <h3 className="mb-3 text-sm font-semibold text-slate-300">健康因子</h3>
      <div className="mb-2 flex items-end justify-between">
        <span
          className={`text-3xl font-bold ${canLiquidate ? "text-red-400" : "text-emerald-400"}`}
        >
          {label}
        </span>
        <span className="text-xs text-slate-500">安全线 1.0</span>
      </div>
      <div className="h-3 overflow-hidden rounded-full bg-slate-800">
        <div className={`h-full ${color} transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <p className="mt-2 text-xs text-slate-400">
        {canLiquidate ? "账户可被清算" : isVeryHealthy ? "无债务或仓位非常安全" : hf >= 1 ? "仓位健康" : "接近清算线"}
      </p>
    </div>
  );
}

export function PositionOverview({
  debt,
  usdkBalance,
  maxSafeMint,
  collateral,
}: {
  debt: string;
  usdkBalance: string;
  maxSafeMint: string;
  collateral: { symbol: string; deposited: string; walletBalance: string; usdPrice: string }[];
}) {
  const fmt = (v: string) => (Number(v) / 1e18).toFixed(4);

  return (
    <div className="card">
      <h3 className="mb-3 text-sm font-semibold text-slate-300">仓位概览</h3>
      <dl className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="text-slate-500">债务 (USDK)</dt>
          <dd className="font-mono">{fmt(debt)}</dd>
        </div>
        <div>
          <dt className="text-slate-500">USDK 余额</dt>
          <dd className="font-mono">{fmt(usdkBalance)}</dd>
        </div>
        <div className="col-span-2">
          <dt className="text-slate-500">最大安全铸币量</dt>
          <dd className="font-mono">{fmt(maxSafeMint)}</dd>
        </div>
      </dl>
      <div className="mt-4 space-y-2">
        {collateral.map((c) => (
          <div key={c.symbol} className="rounded-lg bg-slate-950/60 p-2 text-xs">
            <div className="font-semibold text-slate-300">{c.symbol}</div>
            <div className="text-slate-400">
              已存: {fmt(c.deposited)} · 钱包: {fmt(c.walletBalance)} · 价格: $
              {(Number(c.usdPrice) / 1e18).toFixed(2)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
