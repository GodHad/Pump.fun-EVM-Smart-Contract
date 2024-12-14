// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC20.sol";

contract Pair is ReentrancyGuard {
    event Mint(uint256 reserve0, uint256 reserve1, address indexed lp);
    event Burn(uint256 reserve0, uint256 reserve1, address indexed lp);
    event Swap(uint256 amount0In, uint256 amount0Out, uint256 amount1In, uint256 amount1Out);
    event ETHTransferred(address indexed to, uint256 amount);

    address private _factory;
    address private _tokenA;
    address private _tokenB;
    address private lp;

    uint256 private constant MIN_LIQUIDITY = 1 ether; 
    uint256 private constant FEE_RATE = 10; 
    uint256 private constant FEE_BASE = 1000;
    uint256 private constant VIRTUAL_SOL_RESERVES = 30 * 10**18; 
    uint256 private constant VIRTUAL_TOKEN_RESERVES = 1073000191 * 10**18; 
    uint256 private constant MAX_TOTAL_SUPPLY = 10**9 * 10**6; 

    constructor(address factory_, address tokenA_, address tokenB_) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(tokenA_ != address(0), "Zero addresses are not allowed.");
        require(tokenB_ != address(0), "Zero addresses are not allowed.");

        _factory = factory_;
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    function mint(uint256 amountVLX, address _lp) external returns (bool) {
        require(_lp != address(0), "Zero address is not allowed.");
        require(amountVLX > 0, "Amount must be positive.");

        lp = _lp;

        uint256 tokenAmount = calculateTokenAmount(amountVLX);

        ERC20(_tokenB).mint(_lp, tokenAmount);

        emit Mint(amountVLX, tokenAmount, _lp);

        return true;
    }

    function swap(uint256 amount0In, uint256 amount0Out, uint256 amount1In, uint256 amount1Out) external returns (bool) {
        require(amount0In > 0 || amount1In > 0, "Insufficient input amount");

        if (amount0In > 0) {
            uint256 amountWithFee = applyFee(amount0In);
            uint256 tokenAmount = calculateTokenAmount(amountWithFee); 
            require(tokenAmount <= reserve1(), "Insufficient token reserves");
            ERC20(_tokenA).transferFrom(msg.sender, address(this), amount0In);
            ERC20(_tokenB).transfer(msg.sender, tokenAmount);
        } else if (amount1In > 0) {
            uint256 vlxAmount = calculateVLXAmount(amount1In);
            require(vlxAmount <= reserve0(), "Insufficient VLX reserves");
            ERC20(_tokenB).transferFrom(msg.sender, address(this), amount1In);
            ERC20(_tokenA).transfer(msg.sender, vlxAmount);
        }

        emit Swap(amount0In, amount0Out, amount1In, amount1Out);
        return true;
    }

    function burn(uint256 reserve0, uint256 reserve1, address _lp) external returns (bool) {
        require(_lp != address(0), "Zero address is not allowed.");
        require(lp == _lp, "Only LP holders can call this function.");
        emit Burn(reserve0, reserve1, _lp);
        return true;
    }

    function approval(address _user, address _token, uint256 amount) external nonReentrant returns (bool) {
        require(_user != address(0), "Zero address is not allowed.");
        require(_token != address(0), "Zero address is not allowed.");
        ERC20 token_ = ERC20(_token);
        token_.approve(_user, amount);
        return true;
    }

    function transferETH(address _address, uint256 amount) external returns (bool) {
        require(_address != address(0), "Zero address is not allowed.");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = payable(_address).call{value: amount}("");
        require(success, "Transfer failed");
        emit ETHTransferred(_address, amount);
        return success;
    }

    function liquidityProvider() external view returns (address) {
        return lp;
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function tokenA() external view returns (address) {
        return _tokenA;
    }

    function tokenB() external view returns (address) {
        return _tokenB;
    }

    function reserve0() public view returns (uint256) {
        return IERC20(_tokenA).balanceOf(address(this));
    }

    function reserve1() public view returns (uint256) {
        return IERC20(_tokenB).balanceOf(address(this));
    }

    function kLast() external pure returns (uint256) {
        return 0; 
    }

    function priceALast() external view returns (uint256) {
        uint256 res0 = reserve0();
        require(res0 > 0, "Reserve0 is zero");
        return reserve1() / res0;
    }

    function priceBLast() external view returns (uint256) {
        uint256 res1 = reserve1();
        require(res1 > 0, "Reserve1 is zero");
        return reserve0() / res1;
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return MIN_LIQUIDITY;
    }

    function applyFee(uint256 amount) private pure returns (uint256) {
        return (amount * (FEE_BASE - FEE_RATE)) / FEE_BASE;
    }

    function calculateTokenAmount(uint256 amountVLX) private view returns (uint256) {
        uint256 newReserve0 = VIRTUAL_SOL_RESERVES + amountVLX + reserve0();
        uint256 newReserve1 = VIRTUAL_TOKEN_RESERVES - (VIRTUAL_SOL_RESERVES * VIRTUAL_TOKEN_RESERVES) / newReserve0;
        return reserve1() - newReserve1; 
    }

    function calculateVLXAmount(uint256 amountTokens) private view returns (uint256) {
        uint256 newReserve1 = VIRTUAL_TOKEN_RESERVES - amountTokens + reserve1();
        uint256 newReserve0 = (VIRTUAL_SOL_RESERVES * VIRTUAL_TOKEN_RESERVES) / newReserve1 - VIRTUAL_SOL_RESERVES;
        return newReserve0 - reserve0();
    }
}