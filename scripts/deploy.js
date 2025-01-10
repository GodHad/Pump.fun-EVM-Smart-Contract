const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners(); // Get the deployer account

  console.log("Deploying contracts with the account:", deployer.address);
  const Factory = await hre.ethers.getContractFactory("BaseFunPlatform");
  const factory = await Factory.deploy('0xF19Ac4f314B7eEB29fF74e9c379A375065a44B51'); // Use deployer as feeTo for now
  await factory.waitForDeployment();
  console.log("Factory deployed to:", await factory.getAddress());
  // Deploy Factory
  // const Factory = await hre.ethers.getContractFactory("Factory");
  // const factory = await Factory.deploy(deployer.address); // Use deployer as feeTo for now
  // await factory.waitForDeployment();
  // const factoryAddress = await factory.getAddress()
  // console.log("Factory deployed to:", factoryAddress);

  // //   Deploy Router (replace placeholders with actual addresses)
  // const Router = await hre.ethers.getContractFactory("Router");
  // const router = await Router.deploy(
  //     factoryAddress,s
  //     "0xc579d1f3cf86749e05cd06f7ade17856c2ce3126", // Replace with WVLX token address
  //     2 // Example referral fee
  // );
  // await router.waitForDeployment();
  // const routerAddress = await router.getAddress();
  // console.log("Router deployed to:", routerAddress);

  // // Deploy PumpFun (replace placeholders with actual addresses)
  // const PumpFun = await hre.ethers.getContractFactory("PumpFun");
  // const pumpFun = await PumpFun.deploy(
  //     factoryAddress,
  //     routerAddress,
  //     deployer.address, // Use deployer as feeTo for now
  //     5 // Example fee
  // );
  // await pumpFun.waitForDeployment();
  // const pumpFunAddress = await pumpFun.getAddress();
  // console.log("PumpFun deployed to:", pumpFunAddress);

  // //   Optionally, you can verify the contracts on a block explorer (e.g., Etherscan)
  // if (hre.network.name !== "hardhat") {
  //     await hre.run("verify:verify", {
  //         address: factoryAddress,
  //         constructorArguments: [deployer.address],
  //     });
  //     await hre.run("verify:verify", {
  //         address: routerAddress,
  //         constructorArguments: [deployer.address],
  //     });
  //     await hre.run("verify:verify", {
  //         address: pumpFunAddress,
  //         constructorArguments: [deployer.address],
  //     });
  // }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});