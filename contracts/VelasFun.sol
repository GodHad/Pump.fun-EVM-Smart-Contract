// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Factory.sol";
import "./Pair.sol";

interface IWagyuSwapRouter02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IWagyuSwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract VelasFun is ReentrancyGuard {
    receive() external payable {}

    address private owner;
    Factory private factory;
    address private _feeTo;
    uint256 private fee;
    uint private constant lpFee = 5;
    address private constant WVLX = 0xc579D1f3CF86749E05CD06f7ADe17856c2CE3126;

    struct Token {
        address creator;
        address token;
        address pair;
        Data data;
        string description;
        string image;
        string twitter;
        string telegram;
        string website;
        bool trading;
        bool tradingOnWagyuSwap;
    }

    struct Data {
        address token;
        string name;
        string ticker;
        uint256 supply;
        uint256 price;
        uint256 marketCap;
    }

    mapping(address => Token) public token;
    Token[] public tokens;

    event Launched(address indexed token, address indexed pair, uint);
    event Deployed(address indexed token, uint256 amount0, uint256 amount1);

    constructor(address factory_, address fee_to, uint256 _fee) {
        owner = msg.sender;
        require(factory_ != address(0), "Zero addresses are not allowed.");
        require(fee_to != address(0), "Zero addresses are not allowed.");

        factory = Factory(factory_);
        _feeTo = fee_to;
        fee = (_fee * 1 ether) / 1000;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    function launchFee() public view returns (uint256) {
        return fee;
    }

    function updateLaunchFee(uint256 _fee) public returns (uint256) {
        fee = _fee;
        return _fee;
    }

    function liquidityFee() public pure returns (uint256) {
        return lpFee;
    }

    function feeTo() public view returns (address) {
        return _feeTo;
    }

    function feeToSetter() public view returns (address) {
        return owner;
    }

    function setFeeTo(address fee_to) public onlyOwner {
        require(fee_to != address(0), "Zero addresses are not allowed.");
        _feeTo = fee_to;
    }

    function getTokens() public view returns (Token[] memory) {
        return tokens;
    }

    function launch(string memory _name, string memory _ticker, string memory desc, string memory img, string[3] memory urls, uint256 _supply, uint maxTx) public payable nonReentrant returns (address, address, uint) {
        require(msg.value >= fee, "Insufficient amount sent.");

        ERC20 _token = new ERC20(_name, _ticker, _supply, maxTx);
        address _pair = factory.createPair(address(_token), WVLX);

        Pair pair_ = Pair(payable(_pair));

        uint256 supply = _supply * 10 ** _token.decimals();
        uint256 value = msg.value;

        // Mint tokens dynamically
        uint256 requiredTokens = supply - _token.balanceOf(address(this));
        if (requiredTokens > 0) {
            _token.mint(address(this), requiredTokens); // Mint tokens as needed
        }

        Data memory _data = Data({
            token: address(_token),
            name: _name,
            ticker: _ticker,
            supply: supply,
            price: pair_.calculateAmountOut(0, false), // Get initial price from Pair
            marketCap: pair_.calculateAmountOut(0, false) * supply
        });

        Token memory token_ = Token({
            creator: msg.sender,
            token: address(_token),
            pair: _pair,
            data: _data,
            description: desc,
            image: img,
            twitter: urls[0],
            telegram: urls[1],
            website: urls[2],
            trading: true,
            tradingOnWagyuSwap: false
        });

        token[address(_token)] = token_;
        tokens.push(token_);

        // Transfer fee
        (bool os, ) = payable(_feeTo).call{value: value}("");
        require(os);

        uint n = tokens.length;

        emit Launched(address(_token), _pair, n);

        return (address(_token), _pair, n);
    }

    function getToken(address tk) public view returns (Token memory) {
        return token[tk];
    }

    function _deploy(address tk) private {
        require(tk != address(0), "Zero addresses are not allowed.");

        // Transfer 30,000 VLX deployment fee
        IERC20 wvlxToken = IERC20(WVLX);
        require(wvlxToken.transferFrom(msg.sender, owner, 30_000 * 10 ** 18), "Failed to transfer VLX deployment fee");

        openTradingOnWagyuSwap(tk);
    }

    function openTradingOnWagyuSwap(address tk) private {
        require(tk != address(0), "Zero addresses are not allowed.");

        ERC20 token_ = ERC20(tk);
        Token storage _token = token[tk];

        require(_token.trading && !_token.tradingOnWagyuSwap, "Trading is already open");

        // Dynamic minting can be added here if more tokens are needed for liquidity

        address wagyuSwapPair = IWagyuSwapFactory(IWagyuSwapRouter02(0x0000000000000000000000000000000000000000).factory()).createPair(tk, WVLX);

        IWagyuSwapRouter02(0x0000000000000000000000000000000000000000).addLiquidityETH{value: address(this).balance}(
            tk,
            token_.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );

        IERC20(wagyuSwapPair).approve(address(0x0000000000000000000000000000000000000000), type(uint).max);
    }
}
