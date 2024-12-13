// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC20.sol";

contract Pair is ReentrancyGuard {
    // Events for minting, burning, and swapping
    event Mint(uint256 reserve0, uint256 reserve1, address indexed lp);
    event Burn(uint256 reserve0, uint256 reserve1, address indexed lp);
    event Swap(uint256 amount0In, uint256 amount0Out, uint256 amount1In, uint256 amount1Out);
    event ETHTransferred(address indexed to, uint256 amount);

    // Structure to represent the liquidity pool
    struct Pool {
        uint256 reserve0;
        uint256 reserve1;
        uint256 _reserve1;
        uint256 k;
        uint256 lastUpdated;
    }

    // State variables
    address private _factory;
    address private _tokenA;
    address private _tokenB;
    address private lp;

    Pool private pool;

    // Constants
    uint256 private constant MIN_LIQUIDITY = 1 ether; // Minimum liquidity in the pool
    uint256 private constant FEE_RATE = 10;
    uint256 private constant FEE_BASE = 1000;

    // Constructor
    constructor(address factory_, address tokenA_, address tokenB_) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(tokenA_ != address(0), "Zero addresses are not allowed.");
        require(tokenB_ != address(0), "Zero addresses are not allowed.");

        _factory = factory_;
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    funs

    // Mint liquidity to the pool
    function mint(uint256 reserve0, uint256 reserve1, address _lp) external returns (bool) {
        require(_lp != address(0), "Zero address is not allowed.");
        require(reserve0 > 0 && reserve1 > 0, "Reserves must be positive.");

        lp = _lp;
        
        pool = Pool({
            reserve0: reserve0,
            reserve1: reserve1,
            _reserve1: MIN_LIQUIDITY,
            k: reserve0 * MIN_LIQUIDITY,
            lastUpdated: block.timestamp
        });

        emit Mint(reserve0, reserve1, _lp);

        return true;
    }

    // Swap tokens within the pool
    function swap(uint256 amount0In, uint256 amount0Out, uint256 amount1In, uint256 amount1Out) external returns (bool) {
        uint256 amountWithFee = applyFee(amount0In);
        uint256 newReserve0 = (pool.reserve0 + amountWithFee) - amount0Out;
        uint256 newReserve1 = (pool.reserve1 + amount1In) - amount1Out;
        uint256 newReserve1_ = (pool._reserve1 + amount1In) - amount1Out;

        require(newReserve0 * newReserve1 >= pool.k, "Invariant not maintained");

        pool = Pool({
            reserve0: newReserve0,
            reserve1: newReserve1,
            _reserve1: newReserve1_,
            k: pool.k,
            lastUpdated: block.timestamp
        });

        emit Swap(amount0In, amount0Out, amount1In, amount1Out);

        return true;
    }

    // Burn liquidity from the pool
    function burn(uint256 reserve0, uint256 reserve1, address _lp) external returns (bool) {
        require(_lp != address(0), "Zero address is not allowed.");
        require(lp == _lp, "Only LP holders can call this function.");

        uint256 newReserve0 = pool.reserve0 - reserve0;
        uint256 newReserve1 = pool.reserve1 - reserve1;
        uint256 newReserve1_ = pool._reserve1 - reserve1;

        require(newReserve0 * newReserve1 >= pool.k, "Invariant not maintained");

        pool = Pool({
            reserve0: newReserve0,
            reserve1: newReserve1,
            _reserve1: newReserve1_,
            k: pool.k,
            lastUpdated: block.timestamp
        });

        emit Burn(reserve0, reserve1, _lp);

        return true;
    }

    // Approve a user's token transfer
    function approval(address _user, address _token, uint256 amount) external nonReentrant returns (bool) {
        require(_user != address(0), "Zero address is not allowed.");
        require(_token != address(0), "Zero address is not allowed.");

        ERC20 token_ = ERC20(_token);
        token_.approve(_user, amount);

        return true;
    }

    // Transfer ETH to a specified address
    function transferETH(address _address, uint256 amount) external returns (bool) {
        require(_address != address(0), "Zero address is not allowed.");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = payable(_address).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit ETHTransferred(_address, amount);
        return success;
    }

    // Getters for contract information
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

    function getReserves() external view returns (uint256, uint256, uint256) {
        return (pool.reserve0, pool.reserve1, pool._reserve1);
    }

    function kLast() external view returns (uint256) {
        return pool.k;
    }

    function priceALast() external view returns (uint256) {
        require(pool.reserve0 > 0, "Reserve0 is zero");
        return pool.reserve1 / pool.reserve0;
    }

    function priceBLast() external view returns (uint256) {
        require(pool.reserve1 > 0, "Reserve1 is zero");
        return pool.reserve0 / pool.reserve1;
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return MIN_LIQUIDITY;
    }
}
