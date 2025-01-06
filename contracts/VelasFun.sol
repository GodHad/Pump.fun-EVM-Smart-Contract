// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

contract BaseFunPlatform is Ownable, ReentrancyGuard {
    uint256 public CREATION_FEE = 0.0006 ether;
    uint256 private feePercent = 1;
    uint256 private creatorReward = 0.03 ether;
    uint256 private baseFunReward = 0.5 ether;
    uint256 private GRADUATION_MARKET_CAP = 5 ether;
    address private feeAddress;

    bool private paused = false;
    address[] public admin;

    uint256 public constant INITIAL_VIRTUAL_VLX = 1.8 ether;
    uint256 public constant INITIAL_VIRTUAL_TOKENS = 1_087_598_453 * 10 ** 6;
    uint256 public constant K = INITIAL_VIRTUAL_VLX * INITIAL_VIRTUAL_TOKENS;

    IUniswapV2Router02 private uniswapV2Router;

    mapping(address => TokenInfo) private tokens;
    address[] private tokenList;

    event TokenCreated(address indexed tokenAddress, address indexed creator, string name, string symbol, uint256 amount, uint256 price, uint256 reserve0, uint256 reserve1);
    event TokenPurchased(address indexed buyer, address indexed tokenAddress, uint256 amount, uint256 price, uint256 reserve0, uint256 reserve1);
    event TokenSold(address indexed seller, address indexed tokenAddress, uint256 tokensSold, uint256 price, uint256 reserve0, uint256 reserve1);
    event VariablesUpdated(bool paused, address[] admin, uint256 creationFee, uint256 feePercent, uint256 creatorReward, uint256 baseFunReward, address feeAddress);
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

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Caller is not an admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() Ownable(msg.sender) {
        admin.push(msg.sender);
        feeAddress = msg.sender;
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
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
        address memory _feeAddress
    ) external onlyAdmin {
        require(_feePercent <= 100, "Invalid transaction fee");
        paused = _paused;

        delete admin;

        for (uint256 i = 0; i < _admin.length; i++) {
            address adminAddress = _admin[i];
            require(adminAddress != address(0), "Invalid admin address");
            admin.push(adminAddress);
        }
        CREATION_FEE = _creationFee * 1 ether;
        feePercent = _feePercent;
        creatorReward = _creatorReward * 1 ether;
        baseFunReward = _baseFunReward * 1 ether;
        GRADUATION_MARKET_CAP = _graduationMarketCap * 1 ether;
        feeAddress = _feeAddress;

        emit VariablesUpdated(paused, admin, CREATION_FEE, feePercent, creatorReward, baseFunReward, feeAddress);
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
        uint256 vlxAmount
    ) external payable whenNotPaused {
        require(msg.value >= CREATION_FEE + vlxAmount, "Insufficient value");

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
            tradingPaused: false
        });
        tokenList.push(address(token));

        uint256 remainingAmount = msg.value - CREATION_FEE;
        uint256 feeAmount = (remainingAmount * feePercent) / 100;
        uint256 effectiveAmount = remainingAmount - feeAmount;

        transferFee(remainingAmount);

        TokenInfo storage tokenInfo = tokens[address(token)];
        uint256 price = getTokenPrice(tokenInfo.totalSold);

        uint256 tokensToBuy = effectiveAmount / price;
        uint256 tokenBalance = Memecoin(address(token)).balanceOf(address(this));

        require(tokensToBuy <= tokenBalance, "Not enough tokens available");

        Memecoin(address(token)).transfer(msg.sender, tokensToBuy);

        tokenInfo.totalSold += effectiveAmount;
        tokenInfo.totalRevenue += effectiveAmount;
        tokenInfo.totalSupply += tokensToBuy;
        
        price = getTokenPrice(tokenInfo.totalSold);
        emit TokenCreated(address(token), msg.sender, name, symbol, vlxAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
    }

    function buyTokens(address tokenAddress, uint256 vlxAmount) external payable nonReentrant whenNotPaused {
        require(!tokens[tokenAddress].tradingPaused, "Trading is currently paused for this token");
        require(tokens[tokenAddress].tokenAddress != address(0), "Token not found");
        require(msg.value == vlxAmount, "SOL amount mismatch");

        uint256 feeAmount = (msg.value * feePercent) / 100;
        uint256 effectiveAmount = msg.value - feeAmount;

        transferFee(msg.value);

        TokenInfo storage tokenInfo = tokens[tokenAddress];

        if (tokenInfo.tradingOnUniswap) {
            _buyTokensOnUniswap(tokenAddress, vlxAmount);
        } else {
            uint256 price = getTokenPrice(tokenInfo.totalSold);
            uint256 tokensToBuy = effectiveAmount / price;
            uint256 tokenBalance = Memecoin(tokenAddress).balanceOf(address(this));

            require(tokensToBuy <= tokenBalance, "Not enough tokens available");

            Memecoin(tokenAddress).transfer(msg.sender, tokensToBuy);

            tokenInfo.totalSold += effectiveAmount;
            tokenInfo.totalRevenue += effectiveAmount;
            tokenInfo.totalSupply += tokensToBuy;

            price = getTokenPrice(tokenInfo.totalSold);

            _checkForGraduation(tokenAddress);
            emit TokenPurchased(msg.sender, tokenAddress, vlxAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
        }
    }

    function sellTokens(address tokenAddress, uint256 tokenAmount) external nonReentrant whenNotPaused {
        require(!tokens[tokenAddress].tradingPaused, "Trading is currently paused for this token");
        require(tokens[tokenAddress].tokenAddress != address(0), "Token not found");

        TokenInfo storage tokenInfo = tokens[tokenAddress];

        if (tokenInfo.tradingOnUniswap) {
            _sellTokensOnUniswap(tokenAddress, tokenAmount);
        } else {
            uint256 price = getTokenPrice(tokenInfo.totalSold);
            uint256 refund = tokenAmount * price;
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

            tokenInfo.totalSold -= effectiveRefund;
            tokenInfo.totalRevenue -= effectiveRefund;
            tokenInfo.totalSupply -= tokenAmount;

            payable(msg.sender).transfer(effectiveRefund);

            price = getTokenPrice(tokenInfo.totalSold);

            _checkForGraduation(tokenAddress);
            emit TokenSold(msg.sender, tokenAddress, tokenAmount, price, tokenInfo.totalSupply, tokenInfo.totalSold);
        }
    }

    function _checkForGraduation(address tokenAddress) private {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        uint256 price = getTokenPrice(tokenInfo.totalSold);
        uint256 marketCap = 1_000_000_000 * price;
        if (marketCap >= GRADUATION_MARKET_CAP && !tokenInfo.tradingOnUniswap) {
            _graduateToUniswap(tokenAddress);
            tokenInfo.graduatedToUniswap = true;
            tokenInfo.uniswapPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(tokenAddress, uniswapV2Router.WETH());
        }
    }

    function _graduateToUniswap(address tokenAddress) private {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        tokenInfo.tradingPaused = true;

        Memecoin token = Memecoin(tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.approve(address(uniswapV2Router), tokenBalance);

        uint256 totalSold = tokenInfo.totalSold;
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
    }

    function _buyTokensOnUniswap(address tokenAddress, uint256 vlxAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = tokenAddress;

        uint256[] memory amounts = uniswapV2Router.getAmountsOut(vlxAmount, path);
        require(amounts[1] > 0, "Insufficient output amount");

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: vlxAmount}(
            amounts[1] * 98 / 100,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function _sellTokensOnUniswap(address tokenAddress, uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        Memecoin token = Memecoin(tokenAddress);
        token.approve(address(uniswapV2Router), tokenAmount);

        address;
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
        if (totalSold == 0) return INITIAL_VIRTUAL_VLX / INITIAL_VIRTUAL_TOKENS;
        uint256 y = INITIAL_VIRTUAL_TOKENS - K / (INITIAL_VIRTUAL_VLX + totalSold);
        return totalSold / y;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
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

        delete admin; // Clear current admin list
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
