async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Get the contract factory for TokenFactory
    const TokenFactory = await ethers.getContractFactory("TokenFactory");

    // Deploy TokenFactory with constructor arguments and gas limit as an override
    const hardhatTokenFactory = await TokenFactory.deploy("Test Token", "TST", 18, {
        gasLimit: 3000000,
    });
    console.log("TokenFactory deployed to:", hardhatTokenFactory.address);

    // Get the contract factory for PumpFun
    const PumpFun = await ethers.getContractFactory("PumpFun");

    // Deploy PumpFun contract with the correct constructor arguments and gas limit override
    const hardhatPumpFun = await PumpFun.deploy("0xD6437Dc6Cc7369E9Fd7444d1618E21fffAD51A75", 1000000000000000n, 100n, {
        gasLimit: 3000000,
    });

    console.log("PumpFun deployed to:", hardhatPumpFun.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
