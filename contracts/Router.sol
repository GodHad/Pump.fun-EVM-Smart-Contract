// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import 'hardhat/console.sol';

import "./Factory.sol";
import "./Pair.sol";
import "./ERC20.sol";

contract Router is ReentrancyGuard {
    using SafeMath for uint256;

    address private _factory;

    address private _WETH;

    uint public referralFee;
    
    constructor(address factory_, address weth, uint refFee) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(weth != address(0), "Zero addresses are not allowed.");

        _factory = factory_;

        _WETH = weth;

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

    function _getAmountsOut(address token, address weth, uint256 amountIn) private view returns (uint256 _amountOut) {
        require(token != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);

        address pair = factory_.getPair(token, _WETH);
        Pair _pair = Pair(payable(pair));

        (uint256 reserveA, uint256 _reserveB, ) = _pair.getReserves();

        uint256 k = _pair.kLast();

        uint256 amountOut;
        if(weth == _WETH) {
            uint256 newReserveB = _reserveB.add(amountIn);

            uint256 newReserveA = k.div(newReserveB, "Division failed");
            console.log("reserves: ", reserveA, newReserveA);
            amountOut = reserveA.sub(newReserveA, "Subtraction failed.");
        } else {
            uint256 newReserveA = reserveA.add(amountIn);

            uint256 newReserveB = k.div(newReserveA, "Division failed");

            amountOut = _reserveB.sub(newReserveB, "Subtraction failed.");
        }

        return amountOut;
    }

    function getAmountsOut(address token, address weth, uint256 amountIn) external nonReentrant returns (uint256 _amountOut) {
        uint256 amountOut = _getAmountsOut(token, weth, amountIn);

        return amountOut;
    }

    function _addLiquidityETH(address token, uint256 amountToken, uint256 amountETH) private returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);

        address pair = factory_.getPair(token, _WETH);

        Pair _pair = Pair(payable(pair));

        ERC20 token_ = ERC20(token);

        bool os = transferETH(pair, amountETH);
        require(os, "Transfer of ETH to pair failed.");

        bool os1 = token_.transferFrom(msg.sender, pair, amountToken);
        require(os1, "Transfer of token to pair failed.");
        
        _pair.mint(amountToken, amountETH, msg.sender);

        return (amountToken, amountETH);
    }

    function addLiquidityETH(address token, uint256 amountToken) external payable nonReentrant returns (uint256, uint256) {
        uint256 amountETH = msg.value;

        (uint256 amount0, uint256 amount1) = _addLiquidityETH(token, amountToken, amountETH);
        
        return (amount0, amount1);
    }

    function _removeLiquidityETH(address token, uint256 liquidity, address to) private returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);

        address pair = factory_.getPair(token, _WETH);

        Pair _pair = Pair(payable(pair));

        (uint256 reserveA, , ) = _pair.getReserves();

        ERC20 token_ = ERC20(token);

        uint256 amountETH  = (liquidity * _pair.balance()) / 100;

        uint256 amountToken = (liquidity * reserveA) / 100;

        bool approved = _pair.approval(address(this), token, amountToken);
        require(approved);

        bool os = _pair.transferETH(to, amountETH);
        require(os, "Transfer of ETH to caller failed.");

        bool os1 = token_.transferFrom(pair, to, amountToken);
        require(os1, "Transfer of token to caller failed.");
        
        _pair.burn(amountToken, amountETH, msg.sender);

        return (amountToken, amountETH);
    }

    function removeLiquidityETH(address token, uint256 liquidity, address to) external nonReentrant returns (uint256, uint256) {
        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(token, liquidity, to);

        return (amountToken, amountETH);
    }

    function swapTokensForETH(
        uint256 amountIn,
        address token,
        address to,
        address referree
    ) public nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);

        address pair = factory_.getPair(token, _WETH);
        require(pair != address(0), "Pair does not exist.");

        Pair _pair = Pair(payable(pair));

        ERC20 token_ = ERC20(token);

        // Get the output amount (ETH) for the given input amount (tokens)
        uint256 amountOut = _getAmountsOut(token, _WETH, amountIn);
        // Transfer input tokens to the Pair contract
        bool os = token_.transferFrom(msg.sender, pair, amountIn);
        require(os, "Transfer of token to pair failed.");

        // Calculate transaction fees
        uint fee = factory_.txFee();
        uint256 txFee = (fee * amountOut) / 100;

        uint256 referralAmount = 0;
        uint256 finalAmount = amountOut - txFee;
        console.log("amountOut: ", amountOut);
        // If a referree is provided, calculate and transfer referral fee
        if (referree != address(0)) {
            referralAmount = (referralFee * amountOut) / 100;
            finalAmount -= referralAmount;

            bool os1 = _pair.transferETH(referree, referralAmount);
            require(os1, "Transfer of ETH to referree failed.");
        }
        require(false, 'working to here');

        // Transfer the final amount of ETH to the user
        bool os2 = _pair.transferETH(to, finalAmount);
        require(os2, "Transfer of ETH to user failed.");

        // Transfer the transaction fee to the fee address
        address feeTo = factory_.feeTo();
        bool os3 = _pair.transferETH(feeTo, txFee);
        require(os3, "Transfer of ETH to fee address failed.");

        // Perform the swap
        _pair.swap(amountIn, 0, 0, amountOut);
        
        return (amountIn, amountOut);
    }


    function swapETHForTokens(address token, address to, address referree) public payable nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(referree != address(0), "Zero addresses are not allowed.");

        uint256 amountIn = msg.value;

        Factory factory_ = Factory(_factory);

        address pair = factory_.getPair(token, _WETH);

        Pair _pair = Pair(payable(pair));

        ERC20 token_ = ERC20(token);

        uint256 amountOut = _getAmountsOut(token, address(0), amountIn);

        bool approved = _pair.approval(address(this), token, amountOut);
        require(approved, "Not Approved.");

        uint fee = factory_.txFee();
        uint256 txFee = (fee * amountIn) / 100;
        uint256 _amount;
        uint256 amount;

        if(referree != address(0)) {
            _amount = (referralFee * amountIn) / 100;
            amount = amountIn - (txFee + _amount);

            bool os = transferETH(referree, _amount);
            require(os, "Transfer of ETH to referree failed.");
        } else {
            amount = amountIn - txFee;
        }

        address feeTo = factory_.feeTo();

        bool os1 = transferETH(pair, amount);
        require(os1, "Transfer of ETH to pair failed.");

        bool os2 = transferETH(feeTo, txFee);
        require(os2, "Transfer of ETH to fee address failed.");

        bool os3 = token_.transferFrom(pair, to, amountOut);
        require(os3, "Transfer of token to pair failed.");
    
        _pair.swap(0, amountOut, amount, 0);
        console.log("Pair balance", _pair.balance());
        return (amount, amountOut);
    }
}