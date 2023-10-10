// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";

/// @title MockProtocol
/// @author zeroknots
/// @notice ContractDescription

contract MockProtocol {
    // TODO: add initializer
    function cloneExecutor(address implementation, bytes32 salt) external returns (address proxy) {
        proxy = Clones.predictDeterministicAddress(implementation, salt);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(proxy)
        }
        if (codeSize == 0) {
            proxy = Clones.cloneDeterministic(implementation, salt);
        }
    }

    function cloneExecutor(
        address implementation,
        bytes calldata initCallData,
        bytes32 _userProvidedSalt
    )
        external
        returns (address proxy, bytes32 usedSalt)
    {
        usedSalt = calcSalt(initCallData, _userProvidedSalt);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(proxy)
        }
        if (codeSize == 0) {
            proxy = Clones.cloneDeterministic(implementation, usedSalt);
        }
        if (initCallData.length != 0) {
            (bool success,) = proxy.call(initCallData);
            require(success, "MockProtocol: initCallData failed");
        }
    }

    function getClone(address implementation, bytes32 salt) external view returns (address proxy) {
        proxy = Clones.predictDeterministicAddress(implementation, salt);
    }

    function getClone(
        address implementation,
        bytes calldata initCallData,
        bytes32 _userProvidedSalt
    )
        external
        view
        returns (address proxy, bytes32 usedSalt)
    {
        usedSalt = calcSalt(initCallData, _userProvidedSalt);
        proxy = Clones.predictDeterministicAddress(implementation, usedSalt);
    }

    function calcSalt(
        bytes calldata _initCallData,
        bytes32 _userProvidedSalt
    )
        public
        pure
        returns (bytes32 salt)
    {
        salt = keccak256(abi.encodePacked(_initCallData, _userProvidedSalt));
    }
}
