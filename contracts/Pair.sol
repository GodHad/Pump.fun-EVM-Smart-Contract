// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC20.sol";

contract Pair is ReentrancyGuard {
    address private factory; 
    address private token;  // ERC20 token address
    address private WVLX = 0xc579D1f3CF86749E05CD06f7ADe17856c2CE3126; // Example VLX address

    constructor(address factory_, address token_) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(token_ != address(0), "Zero addresses are not allowed.");

        factory = factory_;
        token = token_;
    }

    // Accept ERC20 tokens
    function acceptTokens(uint256 amount) public nonReentrant {
        ERC20 tokenContract = ERC20(token);

        require(tokenContract.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    receive() external payable {
        require(msg.value > 0, "Must send some VLX (ETH) to the contract.");
    }

    // Helper function to calculate amount out based on bonding curve
    function calculateAmountOut(uint256 amountIn, bool isTokenToVlx) public pure returns (uint256) {
        uint256 initialVirtualVlxReserves = 30 * 10 ** 18;
        uint256 initialTokenReserves = 1_073_000_191 * 10 ** 6;
        uint256 k = 32_190_005_730 * 10 ** 18;

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
    s
}
