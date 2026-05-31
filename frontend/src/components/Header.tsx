import { useState } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { anvilChain } from "../lib/wagmi";

function formatConnectError(message: string): string {
  if (message.includes("Extension context invalidated")) {
    return "MetaMask 扩展已重载，请刷新页面（Cmd+Shift+R）后重试。";
  }
  if (message.includes("User rejected")) {
    return "已取消连接。";
  }
  return message;
}

export function Header() {
  const { address, isConnected, chainId } = useAccount();
  const { connect, connectors, error, isPending, reset } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const [hint, setHint] = useState<string | null>(null);

  const connector = connectors[0];
  const wrongNetwork = isConnected && chainId !== anvilChain.id;
  const connectError = error ? formatConnectError(error.message) : null;

  function handleConnect() {
    setHint(null);
    reset();

    if (typeof window !== "undefined" && !window.ethereum) {
      setHint("未检测到 MetaMask，请先安装扩展。");
      return;
    }

    if (!connector) {
      setHint("没有可用的钱包连接器，请刷新页面。");
      return;
    }

    connect({ connector, chainId: anvilChain.id });
  }

  return (
    <header className="mb-6 border-b border-slate-800 pb-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">USDK Dashboard</h1>
          <p className="text-sm text-slate-400">Anvil 本地链 · 超额抵押稳定币</p>
        </div>
        <div className="flex items-center gap-3">
          {isConnected ? (
            <>
              <span className="font-mono text-xs text-slate-300">{address}</span>
              <button className="btn" onClick={() => disconnect()}>
                断开
              </button>
            </>
          ) : (
            <button className="btn" disabled={isPending} onClick={handleConnect}>
              {isPending ? "连接中..." : "连接 MetaMask"}
            </button>
          )}
        </div>
      </div>

      {(connectError || hint) && (
        <p className="mt-3 text-sm text-red-400">{connectError ?? hint}</p>
      )}

      {wrongNetwork && (
        <div className="mt-3 flex items-center gap-3 rounded-lg border border-amber-800/50 bg-amber-950/30 px-3 py-2 text-sm text-amber-200">
          <span>当前网络不是 Anvil (31337)</span>
          <button
            className="btn text-xs"
            disabled={isSwitching}
            onClick={() => switchChain({ chainId: anvilChain.id })}
          >
            {isSwitching ? "切换中..." : "切换到 Anvil"}
          </button>
        </div>
      )}

      {!isConnected && (
        <p className="mt-3 text-xs text-slate-500">
          首次使用请在 MetaMask 添加网络：RPC http://127.0.0.1:8545，Chain ID 31337。
          若连接报错，先硬刷新页面再试。
        </p>
      )}
    </header>
  );
}
