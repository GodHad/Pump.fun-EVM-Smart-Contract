const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VelasFunPlatform Contract", async function () {
  const [owner, creator, buyer, seller] = await ethers.getSigners();
  it("add the admin", async function () {
    
    const platform = await ethers.getContractAt("VelasFunPlatform", '0x46e281F6C6f3CfBEf9cbAcC7F2bE85e65591F3f0');
    const txUpdate = await platform.connect(owner).updateVariables(
      false,
      [
        '0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596', 
        '0x4191965460D99eA9486519727a91Dbf112bd4d5f',
        '0xb5C64BfD79f0048EA88E1699834273704aBAB3D3',
        '0xd1DD7014C690374e113AF710886097e6B68CBCdF'
      ],
      1,
      1,
      1,
      1,
      '0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596'
    )
  })
  it("should allow a user to sell tokens", async function () {
    // Create a token
    // const arrayOfVelasAddress = [
    //   '0x51E9491aAfaEbd75eCF9bc0436da0ff99C35753A'
    // ]
    // arrayOfVelasAddress.forEach(async element => {
      // const platform = await ethers.getContractAt("VelasFunPlatform", '0x51E9491aAfaEbd75eCF9bc0436da0ff99C35753A');
      // await platform.connect(owner).withdraw();
    // });

    // const VelasFun = await ethers.getContractFactory("VelasFunPlatform");
    // const velasFun = await VelasFun.deploy();
    // await velasFun.waitForDeployment();
    // const velasAddress = await velasFun.getAddress();
    // console.log("Old Velas contract", velasAddress)
    // const platform = await ethers.getContractAt("VelasFunPlatform", await velasFun.getAddress());
    // const creationFee = ethers.parseEther("1");
    // const solAmount = ethers.parseEther("100");
    // await platform.connect(owner).createToken(
    //   "Test Token 1",
    //   "TTKN1",
    //   "A test token",
    //   "https://example.com/image.png",
    //   "https://twitter.com/test",
    //   "https://telegram.me/test",
    //   "https://example.com",
    //   "https://example.com",
    //   solAmount,
    //   { value: creationFee + solAmount }
    // );
    // const tokenList = await platform.connect(owner).getTokenList();
    // const tokenAddress = tokenList[0];
    // // Buy tokens first
    // await platform.connect(owner).buyTokens(tokenAddress, solAmount, { value: solAmount });
    // const memecoin = await ethers.getContractAt("Memecoin", tokenAddress);
    // const platformBalance = await memecoin.balanceOf(velasAddress);
    // console.log("after buying: ", platformBalance)

    // const newVelasFun = await VelasFun.deploy();
    // await newVelasFun.waitForDeployment();
    // const newVelasAddress = await newVelasFun.getAddress();

    // await platform.connect(owner).migrate(newVelasAddress);

    // console.log("New velas fun contract:", newVelasAddress);
    // const newPlatform = await ethers.getContractAt("VelasFunPlatform", newVelasAddress);
    // await newPlatform.connect(owner).confirmMigration(velasAddress);
    // const newPlatformBalance = await memecoin.balanceOf(newVelasAddress)

    // console.log("balances: ", platformBalance, newPlatformBalance)

    // await expect(newPlatformBalance).to.equal(platformBalance)

    // const txUpdate = await platform.connect(owner).updateVariables(
    //   false,
    //   ['0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596', '0x4191965460D99eA9486519727a91Dbf112bd4d5f'],
    //   2,
    //   2,
    //   2,
    //   2,
    //   '0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596'
    // )
    // await expect(txUpdate)
    //   .to.emit(platform, "VariablesUpdated")
    //   .withArgs(
    //     false, // paused
    //     ["0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596", '0x4191965460D99eA9486519727a91Dbf112bd4d5f'], // admin
    //     2000000000000000000n, // creationFee
    //     2, // transactionFee
    //     2000000000000000000n, // creatorReward
    //     2000000000000000000n, // velasFunReward
    //     "0x1066f339C393Cd41D1acF0f0AAE7CDE9f3B30596" // feeAddress
    //   );

    // const tokenList = await platform.connect(owner).getTokenList();
    // const tokenAddress = tokenList[0];
    // console.log('tokenAddress');
    // // Mint tokens to the platform for testing
    // const memecoin = await ethers.getContractAt("Memecoin", tokenAddress);
    // let ownerBalance = await memecoin.balanceOf(owner.address);
    // console.log("after creating: ", ownerBalance)

    // await memecoin.connect(owner).approve(await platform.getAddress(), ownerBalance);

    // // Sell tokens
    // const _ = await memecoin.balanceOf(owner.address);
    // // Check refund
    // const refund = await ethers.provider.getBalance(owner.address);
    // console.log(_, refund)
    // await platform.connect(owner).sellTokens(tokenAddress, ownerBalance);
    // expect(refund).to.be.gt(solAmount); // Buyer should get a refund

  });
});
