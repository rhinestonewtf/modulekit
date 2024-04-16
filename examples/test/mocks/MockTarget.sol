// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) public returns (uint256) {
        value = _value;
        return _value;
    }

    function executeFromExecutor(
        bytes32,
        bytes calldata callData
    )
        external
        returns (bytes[] memory returnData)
    {
        uint256 _value = uint256(bytes32(callData));
        value = _value;
    }
}
