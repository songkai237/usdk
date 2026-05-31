import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { defineChain } from "viem";

export const anvilChain = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
  },
});

export function createWagmiConfig(rpcUrl?: string) {
  return createConfig({
    chains: [anvilChain],
    connectors: [
      injected({
        target: "metaMask",
      }),
    ],
    transports: {
      [anvilChain.id]: http(rpcUrl ?? "http://127.0.0.1:8545"),
    },
  });
}
