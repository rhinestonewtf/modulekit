// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract MockTarget {
    uint256 public value;

    function set(uint256 _value) public returns (uint256) {
        value = _value;
        return _value;
    }
}
