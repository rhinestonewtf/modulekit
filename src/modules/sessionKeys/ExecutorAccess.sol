// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../core/sessionKey/ISessionValidationModule.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";

contract ExecutorAccessKey is ISessionValidationModule {
    struct ExecutorAccess {
        address sessionKeySigner;
        address executor;
        bytes4 executorMethod;
    }

    error InvalidMethod(bytes4);
    error InvalidValue();
    error InvalidAmount();
    error InvalidTarget();
    error InvalidRecipient();

    function encode(ExecutorAccess memory transaction) public pure returns (bytes memory) {
        return abi.encode(transaction);
    }

    function validateSessionParams(
        address destinationContract,
        uint256 callValue,
        bytes calldata callData,
        bytes calldata _sessionKeyData,
        bytes calldata /*_callSpecificData*/
    )
        public
        virtual
        override
        returns (address)
    {
        ExecutorAccess memory access = abi.decode(_sessionKeyData, (ExecutorAccess));

        bytes4 targetSelector = bytes4(callData[:4]);

        if (access.executor != destinationContract) revert InvalidTarget();
        if (access.executorMethod != targetSelector) revert InvalidMethod(targetSelector);
        return access.sessionKeySigner;
    }
}
