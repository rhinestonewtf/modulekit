// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ISessionValidationModule } from "./ISessionValidationModule.sol";

interface ISessionKeyManager {
    type ValidationData is uint256;

    struct SessionData {
        uint48 validUntil;
        uint48 validAfter;
        ISessionValidationModule sessionValidationModule;
        bytes sessionKeyData;
    }

    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    event SessionCreated(address indexed sa, bytes32 indexed sessionDataDigest, SessionData data);
    event SessionDisabled(address indexed sa, bytes32 indexed sessionDataDigest);

    function digest(SessionData memory sessionData) external pure returns (bytes32);
    function disableSession(bytes32 _sessionDigest) external;
    function enableSession(SessionData memory sessionData) external;
    function getSessionData(
        address smartAccount,
        bytes32 sessionDigest
    )
        external
        view
        returns (SessionData memory data);
    function isModuleType(uint256 _type) external pure returns (bool);
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes memory data
    )
        external
        view
        returns (bytes4);
    function name() external pure returns (string memory);
    function onInstall(bytes memory data) external;
    function onUninstall(bytes memory data) external;
    function validateUserOp(
        UserOperation memory userOp,
        bytes32 userOpHash
    )
        external
        returns (ValidationData vd);
    function version() external pure returns (string memory);
}
