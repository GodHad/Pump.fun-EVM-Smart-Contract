const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("VelasFunPlatform Contract", function () {
  let owner, creator, buyer, seller;
  let velasFun, platform, creationFee, solAmount, valueToSend;

  before(async function () {
    [owner, buyer, seller] = await ethers.getSigners();

    // Deploy the contract
    // const VelasFun = await ethers.getContractFactory("BaseFunPlatform");
    // velasFun = await VelasFun.deploy('0xF19Ac4f314B7eEB29fF74e9c379A375065a44B51');
    // await velasFun.waitForDeployment();
    // console.log(await velasFun.getAddress())
    platform = await ethers.getContractAt("BaseFunPlatform", '0x1e6d6876e52dE1fb52De0aB293d8bfd4cF46B2fa');
    const migrateTx = await platform.connect(owner).migrate('0xa22f8a84B1491eBc095302F7359e7359fBbb967d');
    await migrateTx.wait();

    const newPlatform = await ethers.getContractAt("BaseFunPlatform", "0xa22f8a84B1491eBc095302F7359e7359fBbb967d");
    const confirmTx = await newPlatform.connect(owner).confirmMigration('0x1e6d6876e52dE1fb52De0aB293d8bfd4cF46B2fa')
    await confirmTx.wait();

    // Set constants
    creationFee = ethers.parseEther("0.0003");
    solAmount = ethers.parseEther("0");
    valueToSend = creationFee + solAmount;
  });

  it("should allow a user to sell tokens", async function () {
    // const initialOwnerBalance = await ethers.provider.getBalance(owner);
    // // await platform.connect(owner).withdraw();
    // const txOptions = {
    //   gas: 40000000,
    //   gasPrice: ethers.parseUnits('40', "gwei")
    // };
    // const createTx = await platform.connect(owner).createToken(
    //   "Test Token 1",
    //   "TTKN5",
    //   "A test token",
    //   "https://example.com/image.png",
    //   "https://twitter.com/test",
    //   "https://telegram.me/test",
    //   "https://example.com",
    //   "https://example.com",
    //   solAmount,
    //   { value: valueToSend, ...txOptions }
    // );
    // await createTx.wait();

    // // Get the token address
    // const tokenList = await platform.connect(owner).getTokenList();
    // const tokenAddress = tokenList[tokenList.length - 1];
    // let token = await platform.connect(owner).getToken(tokenAddress)
    // console.log(token)
    // solAmount = ethers.parseEther('0.02')
    // // Buy tokens
    // const buyTx = await platform.connect(owner).buyTokens(tokenAddress, solAmount, { value: solAmount, ...txOptions });
    // await buyTx.wait();

    // token = await platform.connect(owner).getToken(tokenAddress);
    // console.log("After buying token info", token)
    
    // // Get the token contract
    // const memecoin = await ethers.getContractAt("Memecoin", tokenAddress);
    // console.log("HEY");
    // // Check platform balance after purchase
    // const platformBalance = await memecoin.balanceOf(await velasFun.getAddress());
    // console.log("Platform balance after purchase: ", platformBalance.toString());

    // // Check owner's balance
    // const ownerBalance = await memecoin.balanceOf(owner);
    // console.log("Owner's token balance: ", ownerBalance.toString());

    // // Sell tokens
    // const approveTx = await memecoin.connect(owner).approve(await velasFun.getAddress(), ownerBalance, txOptions); // Approve the platform to spend tokens
    // await approveTx.wait();

    // const sellTx = await platform.connect(owner).sellTokens(tokenAddress, ownerBalance);
    // await sellTx.wait();

    // token = await platform.connect(owner).getToken(tokenAddress);
    // console.log("After selling token info", token)
    // // Check refund
    // const finalOwnerBalance = await ethers.provider.getBalance(owner);
    // console.log("Owner's ETH balance after selling: ", finalOwnerBalance.toString());
    // expect(finalOwnerBalance).to.be.gt(initialOwnerBalance); // Verify refund
  });
});
