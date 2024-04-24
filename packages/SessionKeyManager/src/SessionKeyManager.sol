// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable function-max-lines*/
/* solhint-disable ordering*/

import {
    ACCOUNT_EXEC_TYPE,
    ERC7579ValidatorLib
} from "modulekit/src/modules/utils/ERC7579ValidatorLib.sol";
import { ERC7579ValidatorBase } from "modulekit/src/modules/ERC7579ValidatorBase.sol";
import { PackedUserOperation, UserOperationLib } from "modulekit/src/external/ERC4337.sol";
import { ISessionValidationModule } from "./ISessionValidationModule.sol";
import { SessionData, SessionKeyManagerLib } from "./SessionKeyManagerLib.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { Execution } from "erc7579/interfaces/IERC7579Account.sol";

contract SessionKeyManager is ERC7579ValidatorBase {
    using UserOperationLib for PackedUserOperation;
    using ERC7579ValidatorLib for PackedUserOperation;
    using ERC7579ValidatorLib for bytes;
    using SessionKeyManagerLib for SessionData;
    using SessionKeyManagerLib for bytes32;

    event SessionCreated(address indexed sa, bytes32 indexed sessionDataDigest, SessionData data);

    event SessionDisabled(address indexed sa, bytes32 indexed sessionDataDigest);

    // For a given Session Data Digest and Smart Account, stores
    // - the corresponding Session Data if the Session is enabled
    // - nothing otherwise
    mapping(bytes32 sessionDataDigest => mapping(address sa => SessionData data)) internal
        _enabledSessionsData;
    mapping(bytes32 sessionDataDigest => mapping(address sa => uint256 nonce)) internal _nonce;

    function disableSession(bytes32 _sessionDigest) external {
        delete _enabledSessionsData[_sessionDigest][msg.sender];
        emit SessionDisabled(msg.sender, _sessionDigest);
    }

    function enableSession(SessionData calldata sessionData) external {
        bytes32 sessionDataDigest_ = sessionData.digest();
        _enabledSessionsData[sessionDataDigest_][msg.sender] = sessionData;
        emit SessionCreated(msg.sender, sessionDataDigest_, sessionData);
    }

    function digest(SessionData calldata sessionData) external pure returns (bytes32) {
        return sessionData.digest();
    }

    function getSessionData(
        address smartAccount,
        bytes32 sessionDigest
    )
        external
        view
        returns (SessionData memory data)
    {
        data = _enabledSessionsData[sessionDigest][smartAccount];
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData vd)
    {
        ACCOUNT_EXEC_TYPE accountExecType = userOp.callData.decodeExecType();

        if (ACCOUNT_EXEC_TYPE.EXEC_SINGLE == accountExecType) {
            return _validateSingleExec(userOp, userOpHash);
        } else if (ACCOUNT_EXEC_TYPE.EXEC_BATCH == accountExecType) {
            return _validateBatchedExec(userOp, userOpHash);
        } else {
            return _validatorError();
        }
    }

    function _validateSingleExec(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/ // TODO: userOpHash is currently not evaluated. DONT USE THIS IN PROD
    )
        internal
        returns (ValidationData vd)
    {
        address smartAccount = userOp.getSender();
        (bytes32 sessionKeyDataDigest, bytes calldata sessionKeySignature) =
            SessionKeyManagerLib.decodeSignatureSingle(userOp.signature);

        SessionData storage sessionData = _enabledSessionsData[sessionKeyDataDigest][smartAccount];

        (address to, uint256 value, bytes calldata callData) =
            ERC7579ValidatorLib.decodeCalldataSingle(userOp.callData);

        (address signer, uint48 validUntil, uint48 validAfter) =
            _validateWithSessionKey(to, value, callData, sessionKeySignature, sessionData);

        bool isValid = SignatureCheckerLib.isValidSignatureNowCalldata(
            signer, sessionKeyDataDigest, sessionKeySignature
        );
        if (!isValid) return _validatorError();

        vd = _packValidationData(!isValid, validUntil, validAfter);
    }

    function _validateBatchedExec(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/
    )
        internal
        returns (ValidationData vd)
    {
        address smartAccount = userOp.getSender();

        // do we need to check userOpHash
        (bytes32[] calldata sessionKeyDataDigests, bytes[] calldata sessionKeySignatures) =
            SessionKeyManagerLib.decodeSignatureBatch(userOp.signature);

        // get ERC7579 Execution struct array from callData
        Execution[] calldata execs = ERC7579ValidatorLib.decodeCalldataBatch(userOp.callData);

        uint256 length = sessionKeySignatures.length;
        if (execs.length != length) {
            return _validatorError();
        }

        uint48 maxValidUntil;
        uint48 minValidAfter;
        for (uint256 i; i < length; i++) {
            // ----- Cached Data -----
            Execution calldata execution = execs[i];
            bytes32 sessionKeyDataDigest = sessionKeyDataDigests[i];
            bytes calldata sessionKeySignature = sessionKeySignatures[i];
            // ----------
            SessionData storage sessionData =
                _enabledSessionsData[sessionKeyDataDigest][smartAccount];
            (address signer, uint48 validUntil, uint48 validAfter) = _validateWithSessionKey(
                execution.target,
                execution.value,
                execution.callData,
                sessionKeySignature,
                sessionData
            );

            bool isValid = SignatureCheckerLib.isValidSignatureNowCalldata(
                signer, sessionKeyDataDigest, sessionKeySignature
            );
            if (!isValid) return _validatorError();
            if (maxValidUntil < validUntil) {
                maxValidUntil = validUntil;
            }
            if (minValidAfter > validAfter) {
                minValidAfter = validAfter;
            }
        }
        return _packValidationData(false, maxValidUntil, minValidAfter);
    }

    function _validateWithSessionKey(
        address to,
        uint256 value,
        bytes calldata callData,
        bytes calldata sessionKeySignature,
        SessionData storage sessionData
    )
        internal
        returns (address signer, uint48 validUntil, uint48 validAfter)
    {
        ISessionValidationModule sessionValidationModule = sessionData.sessionValidationModule;

        signer = sessionValidationModule.validateSessionParams({
            to: to,
            value: value,
            callData: callData,
            sessionKeyData: sessionData.sessionKeyData,
            callSpecificData: sessionKeySignature
        });

        validUntil = sessionData.validUntil;
        validAfter = sessionData.validAfter;
    }

    function _validatorError() internal pure returns (ValidationData vd) {
        return _packValidationData(true, 0, 0);
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    { }

    function name() external pure virtual returns (string memory) {
        return "SessionKeyManager";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 _type) external pure virtual override returns (bool) {
        return _type == TYPE_VALIDATOR;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isInitialized(address smartAccount) external view override returns (bool) { }
}
