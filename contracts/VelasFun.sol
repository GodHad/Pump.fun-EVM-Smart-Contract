// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./Memecoin.sol";

struct TokenInfo {
    address tokenAddress;
    address creator;
    string description;
    string image;
    string twitter;
    string telegram;
    string website;
    uint256 totalSold;
    uint256 totalRevenue;
    uint256 totalSupply;
    bool tradingOnUniswap;
    bool tradingPaused;
    address uniswapPair;
}

interface IBaseFunPlatform {
    function getTokenList() external view returns (address[] memory);
    function getToken(address token) external view returns (TokenInfo memory);
    function setMigrationVariables(
        uint256 _creationFee,
        uint256 _feePercent,
        uint256 _creatorReward,
        uint256 _baseFunReward,
        address _feeAddress,
        bool _paused,
        address[] memory _admin
    ) external;
}

contract BaseFunPlatform is Ownable, ReentrancyGuard {
    using Address for address;
    uint256 public CREATION_FEE = 0.0007 ether;
    uint256 private feePercent = 1;
    uint256 private creatorReward = 0 ether;
    uint256 private baseFunReward = 0 ether;
    uint256 private GRADUATION_MARKET_CAP = 1.75 ether;
    address private feeAddress;

    bool private paused = false;
    address[] public admin;

    uint256 public constant INITIAL_VIRTUAL_ETH = 1.8 ether;
    uint256 public constant INITIAL_VIRTUAL_TOKENS = 1_087_598_453 * 10 ** 6;
    uint256 public constant K = INITIAL_VIRTUAL_ETH * INITIAL_VIRTUAL_TOKENS;

    IUniswapV2Router02 private uniswapV2Router;

    mapping(address => TokenInfo) private tokens;
    address[] private tokenList;

    event TokenCreated(
        address indexed tokenAddress, 
        address indexed creator, 
        string name, 
        string symbol, 
        string description, 
        string image,
        string twitter,
        string telegram,
        string website,
        uint256 amount, 
        uint256 price, 
        uint256 reserve0, 
        uint256 reserve1
    );
    event TokenPurchased(address indexed buyer, address indexed tokenAddress, uint256 amount, uint256 price, uint256 reserve0, uint256 reserve1);
    event TokenSold(address indexed seller, address indexed tokenAddress, uint256 tokensSold, uint256 price, uint256 reserve0, uint256 reserve1);
    event VariablesUpdated(bool paused, address[] admin, uint256 creationFee, uint256 feePercent, uint256 creatorReward, uint256 baseFunReward, address feeAddress, uint256 graduationMarketCap);
    event MigrationComplete(uint256 balance, uint256 tokenLength);
    event MigrationVariablesUpdated(
        uint256 creationFee,
        uint256 feePercent,
        uint256 creatorReward,
        uint256 baseFunReward,
        address feeAddress,
        bool paused,
        address[] admin
    );
    event GraduatingTokenToUniswap(address indexed tokenAddress);
    event TradingEnabledOnUniswap(address indexed tokenAddress, address indexed uniswapPair);

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Caller is not an admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(address _router) Ownable(msg.sender) {
        admin.push(msg.sender);
        feeAddress = msg.sender;
        uniswapV2Router = IUniswapV2Router02(_router);
    }

    function isAdmin(address user) public view returns (bool) {
        for (uint256 i = 0; i < admin.length; i ++) {
            if (admin[i] == user) return true;
        }
        return false;
    }

    function updateVariables(
        bool _paused, 
        address[] calldata _admin, 
        uint256 _creationFee,
        uint256 _feePercent,
        uint256 _creatorReward,
        uint256 _baseFunReward,
        uint256 _graduationMarketCap,
        address _feeAddress
    ) external onlyAdmin {
        require(_feePercent <= 100, "Invalid transaction fee");
        paused = _paused;

        delete admin;

        for (uint256 i = 0; i < _admin.length; i++) {
            address adminAddress = _admin[i];
            require(adminAddress != address(0), "Invalid admin address");
            admin.push(adminAddress);
        }
        CREATION_FEE = _creationFee;
        feePercent = _feePercent;
        creatorReward = _creatorReward;
        baseFunReward = _baseFunReward;
        GRADUATION_MARKET_CAP = _graduationMarketCap;
        feeAddress = _feeAddress;

        emit VariablesUpdated(paused, admin, CREATION_FEE, feePercent, creatorReward, baseFunReward, feeAddress, GRADUATION_MARKET_CAP);
    }

    function transferFee(uint256 amount) internal {
        uint256 feeAmount = (amount * feePercent) / 100;
        payable(feeAddress).transfer(feeAmount);
    }

    function createToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory twitter,
        string memory telegram,
        string memory website,
        string memory metadataURI,
        uint256 ethAmount
    ) external payable whenNotPaused {
        require(msg.value >= CREATION_FEE + ethAmount, "Insufficient value");

        transferFee(CREATION_FEE);

        Memecoin token = new Memecoin(name, symbol, metadataURI, msg.sender);
        tokens[address(token)] = TokenInfo({
            tokenAddress: address(token),
            creator: msg.sender,
            description: description,
            image: image,
            twitter: twitter,
            telegram: telegram,
            website: website,
            totalSold: 0,
            totalRevenue: 0,
            totalSupply: 0,
            tradingOnUniswap: false,
            tradingPaused: false,
            uniswapPair: msg.sender
        });
        tokenList.push(address(token));

        uint256 remainingAmount = msg.value - CREATION_FEE;
        uint256 feeAmount = (remainingAmount * feePercent) / 100;
        uint256 effectiveAmount = remainingAmount - feeAmount;

        transferFee(remainingAmount);

        TokenInfo storage tokenInfo = tokens[address(token)];
        uint256 price = INITIAL_VIRTUAL_ETH / INITIAL_VIRTUAL_TOKENS;

        uint256 tokensToBuy = getTokenPrice(effectiveAmount);
        uint256 tokenBalance = Memecoin(address(token)).balanceOf(address(this));

        require(tokensToBuy <= tokenBalance, "Not enough tokens available");

        Memecoin(address(token)).transfer(msg.sender, tokensToBuy);

        tokenInfo.totalSold += effectiveAmount;
        tokenInfo.totalRevenue += effectiveAmount;
        tokenInfo.totalSupply += tokensToBuy;
        
        if (tokenInfo.totalSupply > 0) price = tokenInfo.totalSold / tokenInfo.totalSupply;

        _checkForGraduation(address(token));
        emit TokenCreated(address(token), msg.sender, name, symbol, description, image, twitter, telegram, website, ethAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
    }

    function buyTokens(address tokenAddress, uint256 ethAmount) external payable nonReentrant whenNotPaused {
        require(!tokens[tokenAddress].tradingPaused, "Trading is currently paused for this token");
        require(tokens[tokenAddress].tokenAddress != address(0), "Token not found");
        require(msg.value == ethAmount, "SOL amount mismatch");

        uint256 feeAmount = (msg.value * feePercent) / 100;
        uint256 effectiveAmount = msg.value - feeAmount;

        transferFee(msg.value);

        TokenInfo storage tokenInfo = tokens[tokenAddress];
        
        uint256 price = INITIAL_VIRTUAL_ETH / INITIAL_VIRTUAL_TOKENS;

        if (tokenInfo.tradingOnUniswap) {
            _buyTokensOnUniswap(tokenAddress, ethAmount);
        } else {
            if (tokenInfo.totalSupply > 0) price = tokenInfo.totalSold / tokenInfo.totalSupply;
            uint256 tokensToBuy = getTokenPrice(tokenInfo.totalSold + effectiveAmount) - tokenInfo.totalSupply;
            uint256 tokenBalance = Memecoin(tokenAddress).balanceOf(address(this));

            require(tokensToBuy <= tokenBalance, "Not enough tokens available");

            Memecoin(tokenAddress).transfer(msg.sender, tokensToBuy);

            tokenInfo.totalSold += effectiveAmount;
            tokenInfo.totalRevenue += effectiveAmount;
            tokenInfo.totalSupply += tokensToBuy;

            price = tokenInfo.totalSold / tokenInfo.totalSupply;

            _checkForGraduation(tokenAddress);
        }
        emit TokenPurchased(msg.sender, tokenAddress, ethAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
    }

    function sellTokens(address tokenAddress, uint256 tokenAmount) external nonReentrant whenNotPaused {
        require(!tokens[tokenAddress].tradingPaused, "Trading is currently paused for this token");
        require(tokens[tokenAddress].tokenAddress != address(0), "Token not found");
        require(tokens[tokenAddress].totalSupply > tokenAmount, "Unexpected error is occurred when selling");

        TokenInfo storage tokenInfo = tokens[tokenAddress];

        uint256 price = INITIAL_VIRTUAL_ETH / INITIAL_VIRTUAL_TOKENS;

        if (tokenInfo.tradingOnUniswap) {
            bool success = Memecoin(tokenAddress).transferFrom(msg.sender, address(this), tokenAmount);
            require(success, "Token transfer failed");
            _sellTokensOnUniswap(tokenAddress, tokenAmount);
        } else {
            if (tokenInfo.totalSupply > 0) price = tokenInfo.totalSold / tokenInfo.totalSupply;
            
            uint256 haveToRemainETH = getTokenETHAmount(tokenInfo.totalSupply - tokenAmount);
            uint256 refund = tokenInfo.totalSold - haveToRemainETH;
            
            require(address(this).balance >= refund, "Not enough SOL in contract");
            uint256 feeAmount = (refund * feePercent) / 100;
            uint256 effectiveRefund = refund - feeAmount;

            transferFee(refund);
            uint256 allowance = Memecoin(tokenAddress).allowance(msg.sender, address(this));
            if (allowance < tokenAmount) {
                Memecoin(tokenAddress).approve(address(this), tokenAmount);
            }
            bool success = Memecoin(tokenAddress).transferFrom(msg.sender, address(this), tokenAmount);
            require(success, "Token transfer failed");

            tokenInfo.totalSold = haveToRemainETH;
            tokenInfo.totalRevenue = haveToRemainETH;
            tokenInfo.totalSupply -= tokenAmount;

            payable(msg.sender).transfer(effectiveRefund);

            price = INITIAL_VIRTUAL_ETH / INITIAL_VIRTUAL_TOKENS;
            if (tokenInfo.totalSupply > 0) price = tokenInfo.totalSold / tokenInfo.totalSupply;

            _checkForGraduation(tokenAddress);
        }
        emit TokenSold(msg.sender, tokenAddress, tokenAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
    }

    function _checkForGraduation(address tokenAddress) private {
        TokenInfo storage tokenInfo = tokens[tokenAddress];

        uint256 price = INITIAL_VIRTUAL_ETH / INITIAL_VIRTUAL_TOKENS;
        if (tokenInfo.totalSupply > 0) price = tokenInfo.totalSold / tokenInfo.totalSupply;
        uint256 marketCap = 1_000_000_000_000_000 * price;
        if (marketCap >= GRADUATION_MARKET_CAP && !tokenInfo.tradingOnUniswap) {
            _graduateToUniswap(tokenAddress);
        }
    }

    function _graduateToUniswap(address tokenAddress) private {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        tokenInfo.tradingPaused = true;
        emit GraduatingTokenToUniswap(tokenAddress);

        Memecoin token = Memecoin(tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.approve(address(uniswapV2Router), tokenBalance);

        uint256 totalSold = tokenInfo.totalSold;
        require(address(this).balance >= totalSold, "Failed to graduation because insufficient ETH balance");

        address uniswapPair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(token), uniswapV2Router.WETH());
        tokenInfo.uniswapPair = uniswapPair;

        payable(tokenInfo.creator).transfer(creatorReward);
        payable(feeAddress).transfer(baseFunReward);
        uint256 remainingAmount = totalSold - creatorReward - baseFunReward;

        uniswapV2Router.addLiquidityETH{value: remainingAmount}(
            tokenAddress,
            tokenBalance,
            0,
            0,
            address(this),
            block.timestamp
        );

        tokenInfo.tradingPaused = false;
        tokenInfo.tradingOnUniswap = true;
        emit TradingEnabledOnUniswap(tokenAddress, uniswapPair);
    }

    function _buyTokensOnUniswap(address tokenAddress, uint256 ethAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = tokenAddress;

        uint256[] memory amounts = uniswapV2Router.getAmountsOut(ethAmount, path);
        require(amounts[1] > 0, "Insufficient output amount");

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            amounts[1] * 98 / 100,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function _sellTokensOnUniswap(address tokenAddress, uint256 tokenAmount) private {
        Memecoin token = Memecoin(tokenAddress);
        token.approve(address(uniswapV2Router), tokenAmount);

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = uniswapV2Router.WETH();

        uint256[] memory amounts = uniswapV2Router.getAmountsOut(tokenAmount, path);
        require(amounts[1] > 0, "Insufficient output amount");

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            amounts[1] * 98 / 100,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function getToken(address token) external view returns (TokenInfo memory) {
        return tokens[token];
    }

    function getTokenList() external view returns (address[] memory) {
        return tokenList;
    }

    function getTokenPrice(uint256 totalSold) public pure returns (uint256) {
        uint256 y = INITIAL_VIRTUAL_TOKENS - K / (INITIAL_VIRTUAL_ETH + totalSold);
        return y;
    }

    function getTokenETHAmount(uint256 y) public pure returns (uint256) {
        uint256 totalSold = K / (INITIAL_VIRTUAL_TOKENS - y) - INITIAL_VIRTUAL_ETH;
        return totalSold;
    }

    function withdraw(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function migrate(address payable newPlatform) external onlyOwner {
        require(newPlatform != address(0), "Invaild new platform address");
        uint256 balance = address(this).balance;
        if (balance > 0) newPlatform.transfer(balance);

        for (uint256 i = 0; i < tokenList.length; i ++) {
            address tokenAddress = tokenList[i];
            uint256 balanceToken = Memecoin(tokenAddress).balanceOf(address(this));
            
            if (balanceToken > 0) {
                Memecoin(tokenAddress).transfer(newPlatform, balanceToken);
            }
        }

        IBaseFunPlatform(newPlatform).setMigrationVariables(
            CREATION_FEE,
            feePercent,
            creatorReward,
            baseFunReward,
            feeAddress,
            paused,
            admin
        );
    }

    function confirmMigration(
        address oldPlatformAddress
    ) external onlyOwner {
        IBaseFunPlatform oldPlatform = IBaseFunPlatform(oldPlatformAddress);
        address[] memory tokenAddresses = oldPlatform.getTokenList();

        for (uint256 i = 0; i < tokenAddresses.length; i ++) {
            address tokenAddress = tokenAddresses[i];
            uint256 balance = Memecoin(tokenAddress).balanceOf(address(this));
            require(balance > 0, "Token not transferred");
            
            tokens[tokenAddress] = oldPlatform.getToken(tokenAddress);

            tokenList.push(tokenAddress);
        }

        uint256 nativeBalance = address(this).balance;
        emit MigrationComplete(nativeBalance, tokenAddresses.length);
    }

    function setMigrationVariables(
        uint256 _creationFee,
        uint256 _feePercent,
        uint256 _creatorReward,
        uint256 _baseFunReward,
        address _feeAddress,
        bool _paused,
        address[] memory _admin
    ) external onlyOwner {
        CREATION_FEE = _creationFee;
        feePercent = _feePercent;
        creatorReward = _creatorReward;
        baseFunReward = _baseFunReward;
        feeAddress = _feeAddress;
        paused = _paused;

        delete admin;
        for (uint256 i = 0; i < _admin.length; i++) {
            admin.push(_admin[i]);
        }

        emit MigrationVariablesUpdated(
            _creationFee,
            _feePercent,
            _creatorReward,
            _baseFunReward,
            _feeAddress,
            _paused,
            _admin
        );
    }

    receive() external payable {}
}
