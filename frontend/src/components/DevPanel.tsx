import { useState } from "react";
import { useWriteContract } from "wagmi";
import type { AppConfig } from "../lib/api";
import { oracleAbi } from "../lib/abis";

type Props = { config: AppConfig };

export function DevPanel({ config }: Props) {
  const { writeContractAsync } = useWriteContract();
  const [wethPrice, setWethPrice] = useState("1700");
  const [wbtcPrice, setWbtcPrice] = useState("4000");
  const [msg, setMsg] = useState<string | null>(null);

  const updateOracle = async (feed: `0x${string}`, priceUsd: string) => {
    const answer = BigInt(Math.floor(parseFloat(priceUsd) * 1e8));
    await writeContractAsync({
      address: feed,
      abi: oracleAbi,
      functionName: "updateAnswer",
      args: [answer],
    });
  };

  const apply = async () => {
    try {
      setMsg(null);
      await updateOracle(config.priceFeeds.weth, wethPrice);
      await updateOracle(config.priceFeeds.wbtc, wbtcPrice);
      setMsg("预言机价格已更新");
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "更新失败");
    }
  };

  return (
    <div className="card space-y-3 border-amber-900/40">
      <h3 className="text-sm font-semibold text-amber-400">Dev · 模拟改价</h3>
      <p className="text-xs text-slate-500">仅 Anvil Mock 预言机。降价后可演示清算。</p>
      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="label">WETH USD</label>
          <input className="input" value={wethPrice} onChange={(e) => setWethPrice(e.target.value)} />
        </div>
        <div>
          <label className="label">WBTC USD</label>
          <input className="input" value={wbtcPrice} onChange={(e) => setWbtcPrice(e.target.value)} />
        </div>
      </div>
      <button className="btn" onClick={apply}>
        更新预言机
      </button>
      {msg && <p className="text-xs text-slate-400">{msg}</p>}
    </div>
  );
}
