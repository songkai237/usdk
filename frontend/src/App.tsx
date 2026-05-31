import { useAccount } from "wagmi";
import { Header } from "./components/Header";
import { HealthGauge, PositionOverview } from "./components/PositionCard";
import { ActionPanel } from "./components/ActionPanel";
import { LiquidatePanel } from "./components/LiquidatePanel";
import { DevPanel } from "./components/DevPanel";
import { useAppConfig, useHealth, usePosition, usePrices } from "./hooks/useApi";

export default function App() {
  const { address, isConnected } = useAccount();
  const { data: config, isLoading: configLoading, error: configError } = useAppConfig();
  const { data: position } = usePosition(address);
  const { data: health } = useHealth(address);
  const { data: prices } = usePrices();

  if (configLoading) {
    return (
      <div className="mx-auto max-w-6xl p-6">
        <p className="text-slate-400">加载配置...</p>
      </div>
    );
  }

  if (configError || !config) {
    return (
      <div className="mx-auto max-w-6xl p-6">
        <p className="text-red-400">
          无法连接 BFF API，请先启动 backend 并执行 make deploy-anvil
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl p-6">
      <Header />

      <div className="mb-4 rounded-lg bg-slate-900/50 px-3 py-2 font-mono text-xs text-slate-500">
        Engine: {config.engine} · USDK: {config.usdk}
        {prices && (
          <span className="ml-4">
            WETH ${(Number(prices.weth) / 1e18).toFixed(0)} · WBTC $
            {(Number(prices.wbtc) / 1e18).toFixed(0)}
          </span>
        )}
      </div>

      {!isConnected ? (
        <p className="text-slate-400">请连接 MetaMask（Anvil 31337）以操作。</p>
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          <div className="space-y-4">
            {health && (
              <HealthGauge
                hfFormatted={health.healthFactorFormatted}
                healthFactor={health.healthFactor}
                canLiquidate={health.canLiquidate}
              />
            )}
            {position && (
              <PositionOverview
                debt={position.debt}
                usdkBalance={position.usdkBalance}
                maxSafeMint={position.maxSafeMint}
                collateral={position.collateral}
              />
            )}
            <DevPanel config={config} />
          </div>
          <div className="space-y-4">
            <ActionPanel config={config} />
            <LiquidatePanel config={config} />
          </div>
        </div>
      )}
    </div>
  );
}
