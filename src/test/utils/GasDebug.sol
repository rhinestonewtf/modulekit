// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract GasDebug {
    event GasUsed(bytes32 key, uint256 phase, uint256 gasUsed);

    mapping(bytes32 key => mapping(uint256 phase => uint256 gas)) internal gasUsed;

    function _logGas(bytes32 _key, uint256 _phase, uint256 _gasUsed) internal {
        gasUsed[_key][_phase] = _gasUsed;
        emit GasUsed(_key, _phase, _gasUsed);
    }

    function getGasUsed(bytes32 key, uint256 phase) public view returns (uint256) {
        return gasUsed[key][phase];
    }
}
