const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VelasFun Contract", function () {
    let VelasFun, velasFun, newToken;
    let owner, addr1, addr2;
    const initialSupply = ethers.parseEther("1000000"); // 1 million tokens
    const feeAddress = "0xYourFeeAddress"; // Update with actual fee address
    const feeAmount = ethers.parseEther("0.1"); // Example fee in ETH

    beforeEach(async function () {
        // Get the signers
        [owner, addr1, addr2] = await ethers.getSigners();
        const Factory = await ethers.getContractFactory('Factory');
        const factory = await Factory.deploy(owner.address);
        await factory.waitForDeployment();
        // Deploy the VelasFun contract
        const Router = await ethers.getContractFactory('Router');
        const router = await Router.deploy(await factory.getAddress(), '0xc579d1f3cf86749e05cd06f7ade17856c2ce3126', 5);
        await router.waitForDeployment();

        VelasFun = await ethers.getContractFactory("VelasFun");
        velasFun = await VelasFun.deploy(await factory.getAddress(), await router.getAddress(), owner.address, 1);
        await velasFun.waitForDeployment(); // Wait for deployment
        const velasFunAddress = await velasFun.getAddress();
        console.log("VelasFun deployed at:", velasFunAddress);
    });

    it("Should allow a user to launch a new token with the specified parameters", async function () {
        const name = "TestToken";
        const symbol = "TT";
        const decimals = 18;
        const totalSupply = ethers.parseEther("1000000"); // 1 million tokens
        const maxTx = ethers.parseEther("5"); // Max transaction limit
        const tokenFee = ethers.parseEther("0.01"); // Fee per token (ETH)
        const wallet = addr1.address;

        // Call the launch function to create a new token
        const tx = await velasFun.connect(owner).launch(
            name,
            symbol,
            'decimals',
            'image',
            ["", "", ""],
            1000000,
            1,
            { value: ethers.parseEther('1') }
        );
        const receipt = await tx.wait();
        const newTokenAddress = receipt.logs[receipt.logs.length - 1].args[0];
        const pairAddress = receipt.logs[receipt.logs.length - 1].args[1];
        console.log(newTokenAddress);
        // Fetch the new token contract
        newToken = await ethers.getContractAt("contracts/ERC20.sol:ERC20", newTokenAddress);
        expect(await newToken.name()).to.equal(name);
        expect(await newToken.symbol()).to.equal(symbol);
        //   expect(await newToken.decimals()).to.equal(decimals);
        expect(await newToken.totalSupply()).to.equal(totalSupply, "Total supply mismatch.");

        const buyAmountInEth = ethers.parseEther("1"); // Buying with 1 ETH
    
        const swapTx = await velasFun.connect(owner).swapETHForTokens(await newToken.getAddress(), addr1.address, addr2.address, {
            value: buyAmountInEth,
        });
        await swapTx.wait();
    
        const tokenBalance = await newToken.balanceOf(addr1);
        console.log("Addr1 Token Balance After Buying:", tokenBalance.toString(), await newToken.getAddress());
    
        expect(tokenBalance).to.be.gt(0, "User should receive tokens after swapping ETH");
    
        // Perform the swap using VelasFun's swapTokensToETH
        await newToken.connect(addr1).approve(await velasFun.getAddress(), 100000)
        const allowance = await newToken.allowance(addr1.address, await velasFun.getAddress());
        expect(allowance).to.equal(100000, 'allownace was not set correctly');

        // console.log('pass');

        // const approveTx = await velasFun.connect(addr1).approval(addr1.address, await newToken.getAddress(), 100000);
        // await expect(approveTx).to.emit(velasFun, 'Approval').withArgs(addr1.address, await newToken.getAddress(), 100000);
        // await approveTx.wait();

        const sellTx = await velasFun.connect(addr1).swapTokensForETH(100000, await newToken.getAddress(), addr1.address, addr2.address);
        await sellTx.wait();
    
        // Check ETH balance after selling
        const ethBalanceAfter = await ethers.provider.getBalance(addr1.address);
        console.log("Addr1 ETH Balance After Selling:", ethBalanceAfter.toString());
    
        // Verify that the token balance is zero after selling
        const tokenBalanceAfter = await newToken.balanceOf(addr1.address);
        expect(tokenBalanceAfter).to.equal(0, "User should have no tokens after selling");
    });
});
