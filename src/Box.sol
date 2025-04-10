// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private number;

    event NumberChanged(uint256 indexed newNumber);

    constructor(address _owner) Ownable(_owner) {}

    function setNumber(uint256 _number) public onlyOwner {
        number = _number;
        emit NumberChanged(_number);
    }

    function getNumber() public view returns (uint256) {
        return number;
    }
}
