// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

abstract contract GasLog {
    event GasLogEvent(bytes32 key, bytes32 id, uint256 gas);

    mapping(bytes32 key => mapping(bytes4 id => uint256 gas)) public gasLog;

    function setGasLog(bytes32 key, bytes4 id, uint256 gas) internal {
        gasLog[key][id] = gas;
        emit GasLogEvent(key, id, gas);
    }

    function supportsGasLog() external pure returns (bool) {
        return true;
    }
}
