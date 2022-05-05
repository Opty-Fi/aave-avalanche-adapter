import { HardhatNetworkForkingUserConfig } from "hardhat/types";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
import { eAvalancheNetwork, iAvalancheParamsPerNetwork } from "./helpers/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const AVALANCHE_RPC_URL = process.env.AVALANCHE_RPC_URL || "";
const FUJI_RPC_URL = process.env.FUJI_RPC_URL || "";
const FORK = process.env.FORK as eAvalancheNetwork;
const FORK_BLOCK_NUMBER = process.env.FORK_BLOCK_NUMBER ? parseInt(process.env.FORK_BLOCK_NUMBER) : 0;

const GWEI = 30 * 1000 * 1000 * 10000;

export const NETWORKS_RPC_URL: iAvalancheParamsPerNetwork<string> = {
  [eAvalancheNetwork.avalanche]: AVALANCHE_RPC_URL,
  [eAvalancheNetwork.fuji]: FUJI_RPC_URL,
};

export const NETWORKS_DEFAULT_GAS: iAvalancheParamsPerNetwork<number | "auto"> = {
  [eAvalancheNetwork.avalanche]: 1 * GWEI,
  [eAvalancheNetwork.fuji]: "auto",
};

export const NETWORKS_CHAIN_ID: iAvalancheParamsPerNetwork<number> = {
  [eAvalancheNetwork.avalanche]: 43114,
  [eAvalancheNetwork.fuji]: 43113,
};

export const BLOCK_TO_FORK = {
  [eAvalancheNetwork.avalanche]: 13734457,
  [eAvalancheNetwork.fuji]: 8694985,
};

export const buildForkConfig = (): HardhatNetworkForkingUserConfig | undefined => {
  if (FORK) {
    const forkMode: HardhatNetworkForkingUserConfig = {
      url: NETWORKS_RPC_URL[FORK],
    };
    if (FORK_BLOCK_NUMBER || BLOCK_TO_FORK[FORK]) {
      forkMode.blockNumber = FORK_BLOCK_NUMBER || BLOCK_TO_FORK[FORK];
    }

    return forkMode;
  }
  return undefined;
};
