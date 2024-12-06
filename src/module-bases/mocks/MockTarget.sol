// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract MockTarget {
    error Unauthorized();

    uint256 public value;

    function set(uint256 _value) public payable returns (uint256) {
        value = _value;
        return _value;
    }

    function setAccessControl(uint256 _value) public returns (uint256) {
        if (msg.sender != address(this)) {
            revert Unauthorized();
        }
        value = _value;
        return _value;
    }
}
