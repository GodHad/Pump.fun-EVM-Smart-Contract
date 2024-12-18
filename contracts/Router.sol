// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC20.sol";
import "./VelasFun.sol";

contract Router is ReentrancyGuard {
    using SafeMath for uint256;

    address private _velasFun;
    address private _factory;
    address private _WETH;
    uint public referralFee;

    uint256 private constant initialVirtualVlxReserves = 30 * 10 ** 18; // 30 VLX in Wei
    uint256 private constant initialTokenReserves = 1_073_000_191 * 10 ** 6; // 1,073,000,191 tokens with 6 decimals
    uint256 private constant k = 32_190_005_730 * 10 ** 18; // Initial k value in Wei
    uint256 private constant mcap = 69_000 * 10 ** 18; // $69k market cap limit in VLX
    
    constructor(address factory_, address weth, address velasFun_, uint refFee) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(weth != address(0), "Zero addresses are not allowed.");

        _factory = factory_;
        _WETH = weth;
        _velasFun = velasFun_;

        require(refFee <= 5, "Referral Fee cannot exceed 5%.");

        referralFee = refFee;
    }

    function factory() public view returns (address) {
        return _factory;
    }

    function WETH() public view returns (address) {
        return _WETH;
    }

    function transferETH(address _address, uint256 amount) private returns (bool) {
        require(_address != address(0), "Zero addresses are not allowed.");
        (bool os, ) = payable(_address).call{value: amount}("");
        return os;
    }

    // Updated for accepting VLX (ETH or native cryptocurrency)
    function swapTokensForVlx(uint256 amountIn, address token) public nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(msg.sender != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);
        address pair = factory_.getPair(token, _WETH);

        ERC20 token_ = ERC20(token);

        uint256 amountOut = calculateAmountOut(amountIn, true);

        bool os = token_.transferFrom(msg.sender, pair, amountIn);
        require(os, "Transfer of token to pair failed");

        uint256 txFee = (amountOut * 1) / 100; // 1% tax

        uint256 amount;
        amount = amountOut - txFee;

        address feeTo = factory_.feeTo();

        // Send VLX to the user (since we are now swapping to VLX)
        bool os2 = transferETH(msg.sender, amount);
        require(os2, "Transfer of VLX to user failed.");

        bool os3 = transferETH(feeTo, txFee);
        require(os3, "Transfer of VLX to fee address failed.");

        return (amountIn, amountOut);
    }

    // Updated for swapping VLX to ERC-20 tokens
    function swapVlxForTokens(address token) public payable nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(msg.sender != address(0), "Zero addresses are not allowed.");
        
        uint256 amountIn = msg.value; // Amount of VLX sent (using msg.value to get VLX)
        Factory factory_ = Factory(_factory);
        address pair = factory_.getPair(token, _WETH); // Get the token-VLX pair address
        
        require(pair != address(0), "Pair does not exist."); // Ensure the pair exists
        
        ERC20 token_ = ERC20(token);

        // Calculate the amount of tokens to receive
        uint256 amountOut = calculateAmountOut(amountIn, false);

        uint256 txFee = (amountIn * 1) / 100; // 1% fee
        uint256 amountToPair = amountIn - txFee; // Amount sent to the pair

        address feeTo = factory_.feeTo();
        // Send VLX to the pair
        (bool sentToPair, ) = pair.call{value: amountToPair}("");
        require(sentToPair, "Transfer of VLX to pair failed.");

        // Send fee to the fee recipient
        (bool sentToFee, ) = payable(feeTo).call{value: txFee}("");
        require(sentToFee, "Transfer of VLX to fee address failed.");

        // Transfer tokens from the pair to the sender
        bool tokenTransfer = token_.transfer(msg.sender, amountOut);
        require(tokenTransfer, "Transfer of token to user failed.");

        require(false, "Working properly to here.");
        return (amountIn, amountOut);
    }

    function calculateAmountOut(uint256 amountIn, bool isTokenToVlx) private pure returns (uint256) {
        if (isTokenToVlx) {
            // Calculate VLX out for given token amount in
            uint256 newTokenReserve = initialTokenReserves + amountIn;
            uint256 newVlxReserve = k / newTokenReserve;
            return initialVirtualVlxReserves - newVlxReserve;
        } else {
            // Calculate token out for given VLX amount in
            uint256 newVlxReserve = initialVirtualVlxReserves + amountIn;
            uint256 newTokenReserve = k / newVlxReserve;
            return initialTokenReserves - newTokenReserve;
        }
    }
}
