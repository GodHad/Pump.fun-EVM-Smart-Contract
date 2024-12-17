// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Factory.sol";
import "./Pair.sol";
import "./ERC20.sol";

interface IYourVelasDEX { 
    function addLiquidityETH(
        address token,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external payable returns (uint amountA, uint amountB, uint liquidity);
}

contract Router is ReentrancyGuard {
    address private _factory;
    address private _WVLX; 

    uint public referralFee;

    constructor(address factory_, address wvlx, uint refFee) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(wvlx != address(0), "Zero addresses are not allowed.");

        _factory = factory_;
        _WVLX = wvlx; 

        require(refFee <= 5, "Referral Fee cannot exceed 5%.");

        referralFee = refFee;
    }

    function factory() public view returns (address) {
        return _factory;
    }

    function WETH() public view returns (address) { 
        return _WVLX; 
    }

    function transferETH(address _address, uint256 amount) private returns (bool) { 
        require(_address != address(0), "Zero addresses are not allowed.");
        (bool os, ) = payable(_address).call{value: amount}("");
        return os;
    }

    function _getAmountsOut(address token, address weth, uint256 amountIn) private view returns (uint256 _amountOut) {
        require(token != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);
        address pairAddress = factory_.getPair(token, _WVLX);
        Pair _pair = Pair(payable(pairAddress));

        (uint256 reserveA, , uint256 reserveB) = _pair.getReserves();
        uint256 k = _pair.kLast();

        uint256 amountOut;

        if (weth == _WVLX) { 
            unchecked { 
                uint256 newReserveB = reserveB + amountIn;
                uint256 newReserveA = k / newReserveB;
                amountOut = reserveA - newReserveA;
            }
        } else {
            unchecked { 
                uint256 newReserveA = reserveA + amountIn;
                uint256 newReserveB = k / newReserveA;
                amountOut = reserveB - newReserveB;
            }
        }

        // Apply fee deduction (adjust percentage as needed)
        amountOut = amountOut * 95 / 100; 

        return amountOut;
    }

    function getAmountsOut(address token, address weth, uint256 amountIn) external nonReentrant returns (uint256 _amountOut) {
        uint256 amountOut = _getAmountsOut(token, weth, amountIn);
        return amountOut;
    }

    function _addLiquidityETH(
        address token, 
        uint256 amountTokenDesired, 
        uint256 amountETHDesired
    ) private returns (uint256 amountToken, uint256 amountETH) {
        require(token != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);
        address pairAddress = factory_.getPair(token, _WVLX); 
        Pair pair = Pair(payable(pairAddress));

        ERC20 token_ = ERC20(token);

        require(
            transferETH(pairAddress, amountETHDesired) && 
            token_.transferFrom(msg.sender, pairAddress, amountTokenDesired), 
            "Transfer failed"
        ); 

        //  Calculate LP tokens to mint
        uint256 totalSupply = IERC20(pairAddress).totalSupply();
        if (totalSupply == 0) {
            amountToken = amountTokenDesired;
            amountETH = amountETHDesired;
        } else {
            uint256 reserve0 = pair.reserve0();
            uint256 reserve1 = pair.reserve1();
            uint256 liquidity = (amountTokenDesired * reserve1) / reserve0;
            if (liquidity < amountETHDesired) {
                amountETH = liquidity;
                amountToken = amountTokenDesired;
            } else {
                amountToken = (amountETHDesired * reserve0) / reserve1;
                amountETH = amountETHDesired;
            }
        }

        // Mint LP tokens to msg.sender (liquidity provider)
        pair.mint(amountToken, msg.sender); 

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
        address pairAddress = factory_.getPair(token, _WVLX);
        Pair _pair = Pair(payable(pairAddress));

        (uint256 reserveA, , ) = _pair.getReserves();
        ERC20 token_ = ERC20(token);

        uint256 amountETH = (liquidity * _pair.balance()) / IERC20(pairAddress).totalSupply(); 
        uint256 amountToken = (liquidity * reserveA) / IERC20(pairAddress).totalSupply(); 

        bool approved = _pair.approval(address(this), token, amountToken);
        require(approved, "Approval failed");

        require(
            _pair.transferETH(to, amountETH) &&
            token_.transferFrom(pairAddress, to, amountToken),
            "Transfer failed"
        );

        _pair.burn(amountETH, amountToken, msg.sender); 

        return (amountToken, amountETH);
    }

    function removeLiquidityETH(address token, uint256 liquidity, address to) external nonReentrant returns (uint256, uint256) {
        (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(token, liquidity, to);
        return (amountToken, amountETH);
    }

    function swapTokensForETH(uint256 amountIn, address token, address to, address referree) public nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(referree != address(0), "Zero addresses are not allowed.");

        Factory factory_ = Factory(_factory);
        address pairAddress = factory_.getPair(token, _WVLX); 
        Pair _pair = Pair(payable(pairAddress));

        ERC20 token_ = ERC20(token);

        uint256 amountOut = _getAmountsOut(token, address(0), amountIn);

        require(token_.transferFrom(to, pairAddress, amountIn), "Transfer of token to pair failed");

        uint fee = factory_.txFee();

        uint256 txFee = (fee * amountOut) / 100;
        uint256 _amount;
        uint256 amount;
        unchecked { 

            if (referree != address(0)) {
                _amount = (referralFee * amountOut) / 100;
                amount = amountOut - (txFee + _amount);

                require(_pair.transferETH(referree, _amount), "Transfer of ETH to referree failed.");
            } else {
                amount = amountOut - txFee;
            }

            address feeTo = factory_.feeTo();

            require(
                _pair.transferETH(to, amount) &&
                _pair.transferETH(feeTo, txFee),
                "ETH transfer failed"
            ); 
        }

        _pair.swap(amountIn, 0, 0, amount); 

        return (amountIn, amount);
    }

    function swapETHForTokens(address token, address to, address referree) public payable nonReentrant returns (uint256, uint256) {
        require(token != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(referree != address(0), "Zero addresses are not allowed.");

        uint256 amountIn = msg.value;

        Factory factory_ = Factory(_factory);
        address pairAddress = factory_.getPair(token, _WVLX); 
        Pair _pair = Pair(payable(pairAddress));
        
        ERC20 token_ = ERC20(token);

        uint256 amountOut = _getAmountsOut(token, _WVLX, amountIn); 

        bool approved = _pair.approval(address(this), token, amountOut);
        require(approved, "Not Approved.");

        uint fee = factory_.txFee();

        uint256 txFee = (fee * amountIn) / 100;
        uint256 _amount;
        uint256 amount;
        unchecked {

            if (referree != address(0)) {
                _amount = (referralFee * amountIn) / 100;
                amount = amountIn - (txFee + _amount);

                require(transferETH(referree, _amount), "Transfer of ETH to referree failed.");
            } else {
                amount = amountIn - txFee;
            }

            address feeTo = factory_.feeTo();

            require(
                transferETH(pairAddress, amount) &&
                transferETH(feeTo, txFee),
                "ETH transfer failed"
            );
        }

        require(token_.transferFrom(pairAddress, to, amountOut), "Transfer of token to pair failed.");

        _pair.swap(0, amountOut, amount, 0); 

        return (amount, amountOut);
    }
/*
    function addLiquidityToDEX(
        address sender, 
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external payable nonReentrant returns (uint amountA, uint amountB, uint liquidity) {
        ERC20(tokenA).transferFrom(sender, address(this), amountADesired);
        ERC20(tokenA).approve(your_velas_dex_address, amountADesired); 

        (amountA, amountB, liquidity) = IYourVelasDEX(your_velas_dex_address).addLiquidityETH{value: msg.value}( 
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }
    */
}