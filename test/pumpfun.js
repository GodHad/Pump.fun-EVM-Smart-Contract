const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PumpFun DEX - End-to-End Test", function () {
    it("Should create a token, buy, and sell tokens", async function () {
        const [owner] = await ethers.getSigners();

        const TestFactory = await ethers.getContractFactory("Factory");
        const factory = await TestFactory.deploy(owner.address);
        await factory.waitForDeployment();
        const factoryAddress = await factory.getAddress();
        console.log('Factory deployed to: ', await factory.getAddress());

        const TestPumpFun = await ethers.getContractFactory("VelasFun");
        const pumpFun = await TestPumpFun.deploy(
            factoryAddress,
            owner.address,
            5
        );
        const pumpFunAddress = await pumpFun.getAddress();
        console.log('Velas deployed to: ', pumpFunAddress);
        const TestRouter = await ethers.getContractFactory("Router");
        const router = await TestRouter.deploy(
            factoryAddress,
            "0xc579d1f3cf86749e05cd06f7ade17856c2ce3126", // Replace with WVLX address
            pumpFunAddress,
            1
        );
        await router.waitForDeployment();
        const routerAddress = await router.getAddress()
        console.log('Router deployed to: ', routerAddress);


        // Launch a new token
        const urls = ['https://twitter.com', 'https://telegram.com', 'https://website.com'];

        const launchTx = await pumpFun.launch("TestToken",
            "TTK",
            "A test token",
            "image.png",
            urls,
            1000000, // Supply
            5, {
            value: ethers.parseEther('0.02'),
        });
        const launchReceipt = await launchTx.wait();
        // console.log(launchReceipt);
        // const event = launchReceipt.events.find(event => event.event === 'Launched');
        // console.log(event)
        const tokenAddress = launchReceipt.logs[launchReceipt.logs.length - 1].args[0]; // Get the token address

        console.log("Token Address:", tokenAddress); // Log the token address
        // console.log("Token Address:", otherAddress); // Log the token address

        // Buy tokens (swap ETH for tokens)
        const buyTx = await router.swapVlxForTokens(
            tokenAddress,
            { 
                value: ethers.parseEther("1") ,
                sender: owner.address
            }
        );
        console.log("Buy transaction hash:", buyTx.hash); // Log the transaction hash
        await buyTx.wait();

        // Check owner's token balance after buying
        const ownerBalanceAfterBuy = await erc20Token.balanceOf(owner.address);
        expect(ownerBalanceAfterBuy).to.be.gt(0); // Greater than 0

        // Sell tokens (swap tokens for ETH)
        const sellTx = await router.swapTokensForVlx(
            ethers.parseEther("50"), // Amount of tokens to sell
            tokenAddress,
            {
                sender: owner.address
            }
        );
        await sellTx.wait();

        // Check owner's token balance after selling
        const ownerBalanceAfterSell = await erc20Token.balanceOf(owner.address);
        expect(ownerBalanceAfterSell).to.be.lt(ownerBalanceAfterBuy); // Less than balance after buying
    });
});