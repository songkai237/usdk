import type { Config } from "wagmi";
import { readContract, WriteContractReturnType } from "wagmi/actions";
import type { Abi, Address } from "viem";
import erc20Abi from "../abi/ERC20Mock.json";

export async function ensureAllowance(
  wagmiConfig: Config,
  writeContractAsync: (args: {
    address: Address;
    abi: Abi;
    functionName: string;
    args: readonly unknown[];
  }) => Promise<WriteContractReturnType>,
  token: Address,
  owner: Address,
  spender: Address,
  amount: bigint,
) {
  const allowance = (await readContract(wagmiConfig, {
    address: token,
    abi: erc20Abi,
    functionName: "allowance",
    args: [owner, spender],
  })) as bigint;

  if (allowance >= amount) return;

  await writeContractAsync({
    address: token,
    abi: erc20Abi,
    functionName: "approve",
    args: [spender, amount],
  });
}
