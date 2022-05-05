import { task, types } from "hardhat/config";
import { utils } from "ethers";
import { AaveV2AvalancheAdapter, AaveV2AvalancheAdapter__factory } from "../../typechain";

task("deploy-aavev2.finance-adapter", "Deploy Aave V2 Adapter")
  .addParam("registry", "the address of registry", "", types.string)
  .setAction(async ({ registry }, { ethers }) => {
    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!utils.isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    const AaveAdapterFactory: AaveV2AvalancheAdapter__factory = await ethers.getContractFactory(
      "AaveV2AvalancheAdapter",
    );
    const AaveAdapter: AaveV2AvalancheAdapter = <AaveV2AvalancheAdapter>await AaveAdapterFactory.deploy(registry);
    await AaveAdapter.deployed();
    console.log("AaveAdapter deployed to: ", AaveAdapter.address);
  });
