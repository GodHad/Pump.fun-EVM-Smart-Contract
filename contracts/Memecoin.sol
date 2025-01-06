// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Memecoin is ERC20 {
    address public creator;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 6;
    string private _tokenURI;

    constructor(string memory name, string memory symbol, string memory tokenMetadataURI, address creatorAddress) ERC20(name, symbol) {
        _mint(msg.sender, TOTAL_SUPPLY);
        _tokenURI = tokenMetadataURI;
        creator = creatorAddress;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function tokenURI() public view returns (string memory) {
        return _tokenURI;
    }
}
