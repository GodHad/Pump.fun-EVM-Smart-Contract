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
    uint256 public kLast; // Reserves product constant

    constructor(address factory_, address tokenA_, address tokenB_) {
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(tokenA_ != address(0), "Zero addresses are not allowed.");
        require(tokenB_ != address(0), "Zero addresses are not allowed.");

        _factory = factory_;
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    // This function should only be callable by the Router contract
    function mint(uint256 amountVLX, address _lp) external returns (bool) {
        require(msg.sender == address(Router(Factory(_factory).feeTo())), "Only the router can call this function.");
        require(_lp != address(0), "Zero address is not allowed.");

        lp = _lp;

        uint256 tokenAmount = calculateTokenAmount(amountVLX);

        ERC20(_tokenB).mint(_lp, tokenAmount);

        _update(reserve0(), reserve1()); 

        emit Mint(amountVLX, tokenAmount, _lp);

        return true;
    }

    function swap(uint256 amount0In, uint256 amount0Out, uint256 amount1In, uint256 amount1Out) external returns (bool) {
        require(amount0In > 0 || amount1In > 0, "Insufficient input amount");
        require(msg.sender == address(Router(Factory(_factory).feeTo())), "Only the router can call this function.");

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

        _update(reserve0(), reserve1());

        emit Swap(amount0In, amount0Out, amount1In, amount1Out);
        return true;
    }

    function burn(uint256 amountVLX, uint256 amountToken, address _lp) external returns (bool) {
        require(_lp != address(0), "Zero address is not allowed.");
        require(lp == _lp, "Only LP holders can call this function.");

        // Add any necessary logic for burning LP tokens and transferring 
        // the underlying tokens (amountVLX and amountToken) to the user (_lp)
        // ...

        emit Burn(amountVLX, amountToken, _lp);
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
        require(_tokenA != address(0), "Pair: Token A is not set");
        return IERC20(_tokenA).balanceOf(address(this));
    }

    function reserve1() public view returns (uint256) {
        require(_tokenB != address(0), "Pair: Token B is not set");
        return IERC20(_tokenB).balanceOf(address(this));
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _kLast, uint256 _reserve1) {
        _reserve0 = reserve0();
        _reserve1 = reserve1();
        _kLast = kLast; 
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    function MINIMUM_LIQUIDITY() external pure returns (uint256) {
        return MIN_LIQUIDITY;
    }

    function applyFee(uint256 amount) private pure returns (uint256) {
        return amount * (FEE_BASE - FEE_RATE) / FEE_BASE; 
    }

    // Updated to implement the PumpFun bonding curve formula
    function calculateTokenAmount(uint256 amountVLX) public view returns (uint256) {
        require(amountVLX > 0, "Amount must be positive");
        uint256 newReserve0 = VIRTUAL_SOL_RESERVES + amountVLX + reserve0();
        uint256 newReserve1 = VIRTUAL_TOKEN_RESERVES - (VIRTUAL_SOL_RESERVES * VIRTUAL_TOKEN_RESERVES) / newReserve0;
        return reserve1() - newReserve1; 
    }

    // Updated to implement the inverse of the PumpFun bonding curve formula
    function calculateVLXAmount(uint256 amountTokens) public view returns (uint256) {
        uint256 newReserve1 = VIRTUAL_TOKEN_RESERVES - amountTokens + reserve1();
        uint256 newReserve0 = (VIRTUAL_SOL_RESERVES * VIRTUAL_TOKEN_RESERVES) / newReserve1 - VIRTUAL_SOL_RESERVES;
        return newReserve0 - reserve0();
    }

    function _update(uint balance0, uint balance1) private {
        kLast = balance0 * balance1; 
    }
}