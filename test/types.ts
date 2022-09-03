import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Fixture, MockContract } from "ethereum-waffle";
import { AaveV2AvalancheAdapter, AaveV3AvalancheAdapter, TestDeFiAdapter } from "../typechain";

export interface Signers {
  admin: SignerWithAddress;
  owner: SignerWithAddress;
  deployer: SignerWithAddress;
  alice: SignerWithAddress;
  bob: SignerWithAddress;
  charlie: SignerWithAddress;
  dave: SignerWithAddress;
  eve: SignerWithAddress;
  operator: SignerWithAddress;
  riskOperator: SignerWithAddress;
}

export interface PoolItem {
  pool: string;
  lpToken: string;
  tokens: string[];
}

export interface LiquidityPool {
  [name: string]: PoolItem;
}

declare module "mocha" {
  export interface Context {
    aaveAdapter: AaveV2AvalancheAdapter;
    aaveV3Adapter: AaveV3AvalancheAdapter;
    testDeFiAdapter: TestDeFiAdapter;
    mockRegistry: MockContract;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}
