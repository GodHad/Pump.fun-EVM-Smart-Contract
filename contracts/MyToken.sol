// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MyToken {
    uint256 public myNumber;

    function setNumber(uint256 _newNumber) public {
        myNumber = _newNumber;
    }

    function getNumber() public view returns (uint256) {
        return myNumber;
    }
}