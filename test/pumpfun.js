const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PumpFun DEX - End-to-End Test", function () {
    it("Should create a token, buy, and sell tokens", async function () {
        const [owner] = await ethers.getSigners();

        const TestFactory = await ethers.getContractFactory("Factory");
        const factory = await TestFactory.deploy(owner.address);
        await factory.waitForDeployment();
        const factoryAddress = await factory.getAddress()
        console.log('Factory deployed to: ', await factory.getAddress());

        const TestRouter = await ethers.getContractFactory("Router");
        const router = await TestRouter.deploy(
            factoryAddress,
            "0xc579d1f3cf86749e05cd06f7ade17856c2ce3126", // Replace with WVLX address
            2
        );
        await router.waitForDeployment();
        const routerAddress = await router.getAddress()
        console.log('Router deployed to: ', routerAddress);

        const TestPumpFun = await ethers.getContractFactory("PumpFun");
        const pumpFun = await TestPumpFun.deploy(
            factoryAddress,
            routerAddress,
            owner.address,
            5
        );
        console.log('PumpFun deployed to: ', await pumpFun.getAddress());

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
        // console.log(launchReceipt.logs[launchReceipt.logs.length - 1]);
        // const event = launchReceipt.events.find(event => event.event === 'Launched');
        // console.log(event)
        const tokenAddress = launchReceipt.logs[launchReceipt.logs.length - 1].args[0]; // Get the token address

        console.log("Token Address:", tokenAddress); // Log the token address
        // console.log("Token Address:", otherAddress); // Log the token address

        // Get the token contract instance
        const erc20Token = await ethers.getContractAt("contracts/ERC20.sol:ERC20", tokenAddress);

        // Approve the router to spend owner's tokens
        await erc20Token.approve(await router.getAddress(), ethers.parseEther("100"));

        // Buy tokens (swap ETH for tokens)
        const buyTx = await router.swapETHForTokens(
            tokenAddress,
            owner.address,
            owner.address, // Referrer (can be address(0) if not used)
            { value: ethers.parseEther("1") }
        );
        console.log("Buy transaction hash:", buyTx.hash); // Log the transaction hash
        await buyTx.wait();

        // Check owner's token balance after buying
        const ownerBalanceAfterBuy = await erc20Token.balanceOf(owner.address);
        expect(ownerBalanceAfterBuy).to.be.gt(0); // Greater than 0

        // Sell tokens (swap tokens for ETH)
        const sellTx = await router.swapTokensForETH(
            ethers.parseEther("50"), // Amount of tokens to sell
            tokenAddress,
            owner.address,
            owner.address, // Referrer (can be address(0) if not used)
        );
        await sellTx.wait();

        // Check owner's token balance after selling
        const ownerBalanceAfterSell = await erc20Token.balanceOf(owner.address);
        expect(ownerBalanceAfterSell).to.be.lt(ownerBalanceAfterBuy); // Less than balance after buying
    });
});