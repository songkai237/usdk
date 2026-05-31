import { useState } from "react";
import { useAccount, useConfig, useWriteContract } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import type { AppConfig } from "../lib/api";
import { parseUnits } from "../lib/api";
import { engineAbi, erc20Abi } from "../lib/abis";
import { ensureAllowance } from "../lib/contracts";

type Props = { config: AppConfig };

export function ActionPanel({ config }: Props) {
  const { address } = useAccount();
  const wagmiConfig = useConfig();
  const queryClient = useQueryClient();
  const { writeContractAsync } = useWriteContract();

  const [tokenIdx, setTokenIdx] = useState(0);
  const [amount, setAmount] = useState("1");
  const [mintAmount, setMintAmount] = useState("1000");
  const [burnAmount, setBurnAmount] = useState("100");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const token = config.collateralTokens[tokenIdx];
  const engine = config.engine;

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["position", address] });
    queryClient.invalidateQueries({ queryKey: ["health", address] });
  };

  const run = async (fn: () => Promise<void>) => {
    if (!address) return;
    setLoading(true);
    setError(null);
    try {
      await fn();
      invalidate();
    } catch (e) {
      setError(e instanceof Error ? e.message : "交易失败");
    } finally {
      setLoading(false);
    }
  };

  const faucet = () =>
    run(async () => {
      await writeContractAsync({
        address: token.address,
        abi: erc20Abi,
        functionName: "mint",
        args: [address!, parseUnits(amount)],
      });
    });

  const deposit = () =>
    run(async () => {
      const amt = parseUnits(amount);
      await ensureAllowance(wagmiConfig, writeContractAsync, token.address, address!, engine, amt);
      await writeContractAsync({
        address: engine,
        abi: engineAbi,
        functionName: "deposit",
        args: [token.address, amt],
      });
    });

  const redeem = () =>
    run(async () => {
      await writeContractAsync({
        address: engine,
        abi: engineAbi,
        functionName: "redeem",
        args: [token.address, parseUnits(amount)],
      });
    });

  const mint = () =>
    run(async () => {
      await writeContractAsync({
        address: engine,
        abi: engineAbi,
        functionName: "mint",
        args: [parseUnits(mintAmount)],
      });
    });

  const burn = () =>
    run(async () => {
      const amt = parseUnits(burnAmount);
      await ensureAllowance(wagmiConfig, writeContractAsync, config.usdk, address!, engine, amt);
      await writeContractAsync({
        address: engine,
        abi: engineAbi,
        functionName: "burn",
        args: [amt],
      });
    });

  const depositAndMint = () =>
    run(async () => {
      const dep = parseUnits(amount);
      const mint = parseUnits(mintAmount);
      await ensureAllowance(wagmiConfig, writeContractAsync, token.address, address!, engine, dep);
      await writeContractAsync({
        address: engine,
        abi: engineAbi,
        functionName: "depositAndMint",
        args: [token.address, dep, mint],
      });
    });

  return (
    <div className="card space-y-4">
      <h3 className="text-sm font-semibold text-slate-300">操作</h3>

      <div>
        <label className="label">抵押品</label>
        <select
          className="input"
          value={tokenIdx}
          onChange={(e) => setTokenIdx(Number(e.target.value))}
        >
          {config.collateralTokens.map((t, i) => (
            <option key={t.address} value={i}>
              {t.symbol}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="label">数量 (token 单位)</label>
        <input className="input" value={amount} onChange={(e) => setAmount(e.target.value)} />
      </div>

      <div className="flex flex-wrap gap-2">
        <button className="btn" disabled={loading || !address} onClick={faucet}>
          Faucet 领币
        </button>
        <button className="btn" disabled={loading || !address} onClick={deposit}>
          存款
        </button>
        <button className="btn" disabled={loading || !address} onClick={redeem}>
          取款
        </button>
      </div>

      <div>
        <label className="label">铸币 USDK 数量</label>
        <input className="input" value={mintAmount} onChange={(e) => setMintAmount(e.target.value)} />
      </div>
      <div className="flex flex-wrap gap-2">
        <button className="btn" disabled={loading || !address} onClick={mint}>
          铸币
        </button>
        <button className="btn" disabled={loading || !address} onClick={depositAndMint}>
          存款并铸币
        </button>
      </div>

      <div>
        <label className="label">还币 USDK 数量</label>
        <input className="input" value={burnAmount} onChange={(e) => setBurnAmount(e.target.value)} />
      </div>
      <button className="btn" disabled={loading || !address} onClick={burn}>
        还币 (Burn)
      </button>

      {error && <p className="text-sm text-red-400">{error}</p>}
    </div>
  );
}
