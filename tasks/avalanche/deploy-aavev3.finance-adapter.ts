import { task, types } from "hardhat/config";
import { utils } from "ethers";
import { AaveV3AvalancheAdapter, AaveV3AvalancheAdapter__factory } from "../../typechain";

task("deploy-aavev3.finance-adapter", "Deploy Aave V3 Adapter")
  .addParam("registry", "the address of registry", "", types.string)
  .setAction(async ({ registry }, { ethers }) => {
    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!utils.isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    const AaveAdapterFactory: AaveV3AvalancheAdapter__factory = await ethers.getContractFactory(
      "AaveV3AvalancheAdapter",
    );
    const AaveAdapter: AaveV3AvalancheAdapter = <AaveV3AvalancheAdapter>await AaveAdapterFactory.deploy(registry);
    await AaveAdapter.deployed();
    console.log("AaveAdapter deployed to: ", AaveAdapter.address);
  });
