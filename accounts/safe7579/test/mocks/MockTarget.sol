// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockTarget {
    uint256 public value;

    event Access(address sender);

    function set(uint256 _value) public returns (uint256) {
        emit Access(msg.sender);
        value = _value;
        return _value;
    }

    function setAccessControl(uint256 _value) public returns (uint256) {
        if (msg.sender != address(this)) {
            revert("MockTarget: not authorized");
        }
        value = _value;
        return _value;
    }
}
