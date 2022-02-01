// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity ^0.8.10;

contract User {

    mapping(address => string) username;

    function setUsername(string memory _name) public {
        username[msg.sender] = _name;
    }

    function getUsername(address user) public view returns(string memory) {
        return username[user];
    }

}