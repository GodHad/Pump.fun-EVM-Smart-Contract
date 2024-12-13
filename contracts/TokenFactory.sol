// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Token.sol";

interface IPumpFun {
    function createPool(address token, uint256 amount) external payable;
    function getCreateFee() external view returns (uint256);
}

contract TokenFactory {
    uint256 public currentTokenIndex = 0;
    uint256 public constant INITIAL_AMOUNT = 10 ** 27;
    
    address public contractAddress;
    address public taxAddress = 0xD6437Dc6Cc7369E9Fd7444d1618E21fffAD51A75;

    struct TokenStructure {
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
    }

    TokenStructure[] public tokens;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress; // Initialize contract address on deployment
    }

    function deployERC20Token(
        string memory name,
        string memory ticker
    ) public payable {
        Token token = new Token(name, ticker, INITIAL_AMOUNT);

        token.approve(address(this), INITIAL_AMOUNT);
        
        uint256 balance = IPumpFun(contractAddress).getCreateFee();
        require(msg.value >= balance, "Insufficient funds for pool creation");

        IPumpFun(contractAddress).createPool{value: balance}(address(token), INITIAL_AMOUNT);

        tokens.push(TokenStructure(address(token), name, ticker, INITIAL_AMOUNT));

        emit TokenCreated(address(token), name, ticker, INITIAL_AMOUNT);
    }

    function setPoolAddress(address newAddr) public {
        require(newAddr != address(0), "Address cannot be zero");
        contractAddress = newAddr;
    }

    event TokenCreated(address tokenAddress, string tokenName, string tokenSymbol, uint256 totalSupply);
}
