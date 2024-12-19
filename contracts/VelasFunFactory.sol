// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactory is Ownable {
    struct TokenMetadata {
        string name;
        string symbol;
        string image;
        string description;
        string twitter;
        string telegram;
        string website;
    }

    uint256 public constant CREATION_FEE = 0.02 ether; // Fee in VLX
    uint256 public constant LIQUIDITY_THRESHOLD = 69000 ether; // Market cap threshold
    uint256 public constant CREATOR_REWARD = 0.5 ether; // Reward in VLX

    address public dexRouter; // Address of the DEX router for liquidity injection

    mapping(address => TokenMetadata) public tokens;
    address[] public tokenAddresses;

    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol
    );

    constructor(address _dexRouter) {
        require(_dexRouter != address(0), "Invalid DEX router address");
        dexRouter = _dexRouter;
    }

    function createToken(
        string memory name,
        string memory symbol,
        string memory image,
        string memory description,
        string memory twitter,
        string memory telegram,
        string memory website
    ) external payable {
        require(msg.value >= CREATION_FEE, "Insufficient creation fee");
        require(bytes(name).length > 0, "Token name is required");
        require(bytes(symbol).length > 0, "Token symbol is required");

        // Deploy a new token
        CustomToken newToken = new CustomToken(name, symbol, msg.sender, msg.value);

        // Store token metadata
        tokens[address(newToken)] = TokenMetadata(
            name,
            symbol,
            image,
            description,
            twitter,
            telegram,
            website
        );

        tokenAddresses.push(address(newToken));

        emit TokenCreated(address(newToken), msg.sender, name, symbol);
    }

    function getAllTokens() external view returns (address[] memory) {
        return tokenAddresses;
    }

    function setDexRouter(address _dexRouter) external onlyOwner {
        require(_dexRouter != address(0), "Invalid DEX router address");
        dexRouter = _dexRouter;
    }
}

contract CustomToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant VIRTUAL_INITIAL_TOKENS = 1_073_000_191 * 10**18; // Initial virtual token reserve
    uint256 public constant K_MULTIPLIER = 1073000191; // Multiplier for constant product calculation

    uint256 public virtualVlxReserves;
    uint256 public virtualTokenReserves = VIRTUAL_INITIAL_TOKENS;
    uint256 public K;

    constructor(
        string memory name,
        string memory symbol,
        address creator,
        uint256 creationFee
    ) ERC20(name, symbol) {
        require(creationFee > 0, "Creation fee must be greater than 0");
        virtualVlxReserves = creationFee;
        K = creationFee * VIRTUAL_INITIAL_TOKENS / K_MULTIPLIER;
        _mint(creator, INITIAL_SUPPLY);
        transferOwnership(creator);
    }

    function buyTokens() external payable {
        require(msg.value > 0, "Must send VLX to buy tokens");

        uint256 vlxAdded = msg.value;
        uint256 tokensToMint = virtualTokenReserves - (K / (virtualVlxReserves + vlxAdded));

        require(tokensToMint > 0, "Invalid amount of tokens to mint");

        virtualVlxReserves += vlxAdded;
        virtualTokenReserves -= tokensToMint;

        _mint(msg.sender, tokensToMint);
    }

    function sellTokens(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Must sell a valid amount of tokens");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 vlxToReturn = virtualVlxReserves - (K / (virtualTokenReserves + tokenAmount));

        require(vlxToReturn > 0, "Invalid amount of VLX to return");

        virtualVlxReserves -= vlxToReturn;
        virtualTokenReserves += tokenAmount;

        _burn(msg.sender, tokenAmount);
        payable(msg.sender).transfer(vlxToReturn);
    }
}
