// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account, Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { IMSA } from "erc7579/interfaces/IMSA.sol";
import {
    CallType,
    ModeCode,
    ModeLib,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import {
    IValidator,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "erc7579/interfaces/IERC7579Module.sol";
import { AccessControl } from "./core/AccessControl.sol";
import { HookManager } from "./core/HookManager.sol";
import { ISafeOp, SAFE_OP_TYPEHASH } from "./interfaces/ISafeOp.sol";
import { ISafe } from "./interfaces/ISafe.sol";
import {
    PackedUserOperation,
    UserOperationLib
} from "@ERC4337/account-abstraction/contracts/core/UserOperationLib.sol";
import { _packValidationData } from "@ERC4337/account-abstraction/contracts/core/Helpers.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ISafe7579Init } from "./interfaces/ISafe7579Init.sol";
import { IERC1271 } from "./interfaces/IERC1271.sol";

/**
 * @title ERC7579 Adapter for Safe accounts.
 * By using Safe's Fallback and Execution modules,
 * this contract creates full ERC7579 compliance to Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 */
contract SafeERC7579 is
    ISafeOp,
    IERC7579Account,
    ISafe7579Init,
    AccessControl,
    IMSA,
    HookManager
{
    using UserOperationLib for PackedUserOperation;
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    error Unsupported();

    event Safe7579Initialized(address indexed safe);

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256("SafeMessage(bytes message)");
    bytes32 private constant SAFE_MSG_TYPEHASH =
        0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
    // keccak256("safeSignature(bytes32,bytes32,bytes,bytes)");
    bytes4 private constant SAFE_SIGNATURE_MAGIC_VALUE = 0x5fd7e97d;

    /**
     * @inheritdoc IERC7579Account
     */
    function execute(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        override
        withHook // ! this modifier has side effects / external calls
        onlyEntryPointOrSelf
    {
        CallType callType = mode.getCallType();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            _execute(msg.sender, executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) =
                executionCalldata.decodeSingle();
            _execute(msg.sender, target, value, callData);
        } else if (callType == CALLTYPE_DELEGATECALL) {
            address target = address(bytes20(executionCalldata[:20]));
            bytes calldata callData = executionCalldata[20:];
            _executeDelegateCall(msg.sender, target, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        override
        onlyExecutorModule
        withHook // ! this modifier has side effects / external calls
        returns (bytes[] memory returnData)
    {
        CallType callType = mode.getCallType();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            returnData = _executeReturnData(msg.sender, executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) =
                executionCalldata.decodeSingle();
            returnData = new bytes[](1);
            returnData[0] = _executeReturnData(msg.sender, target, value, callData);
        } else if (callType == CALLTYPE_DELEGATECALL) {
            address target = address(bytes20(executionCalldata[:20]));
            bytes calldata callData = executionCalldata[20:];
            returnData = new bytes[](1);
            returnData[0] = _executeDelegateCallReturnData(msg.sender, target, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function executeUserOp(PackedUserOperation calldata userOp)
        external
        payable
        override
        onlyEntryPointOrSelf
    {
        (bool success,) = address(this).delegatecall(userOp.callData[4:]);
        if (!success) revert ExecutionFailed();
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        override
        returns (uint256 validSignature)
    {
        address validator;
        uint256 nonce = userOp.nonce;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            validator := shr(96, nonce)
        }

        // check if validator is enabled. If not, use Safe's checkSignatures()
        if (validator == address(0) || !_isValidatorInstalled(validator)) {
            return _validateSignatures(userOp);
        } else {
            // bubble up the return value of the validator module
            validSignature = IValidator(validator).validateUserOp(userOp, userOpHash);
        }

        // pay prefund
        if (missingAccountFunds != 0) {
            _execute({
                safe: userOp.getSender(),
                target: entryPoint(),
                value: missingAccountFunds,
                callData: ""
            });
        }
    }

    /**
     * Function used as fallback, if no valid validation module was selected.
     * will use safe's ECDSA multisig
     */
    function _validateSignatures(PackedUserOperation calldata userOp)
        internal
        view
        returns (uint256 validationData)
    {
        (
            bytes memory operationData,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signatures
        ) = _getSafeOp(userOp);
        try ISafe(payable(userOp.getSender())).checkSignatures(
            keccak256(operationData), operationData, signatures
        ) {
            // The timestamps are validated by the entry point, therefore we will not check them
            // again
            validationData = _packValidationData(false, validUntil, validAfter);
        } catch {
            validationData = _packValidationData(true, validUntil, validAfter);
        }
    }

    /**
     * Will use Safe's signed messages or checkSignatures features or ERC7579 validation modules
     * if no signature is provided, it makes use of Safe's signedMessages
     * if address(0) or a non-installed validator module is provided, it will use Safe's
     * checkSignatures
     * if a valid validator module is provided, it will use the module's validateUserOp function
     *    @param hash message hash of ERC1271 request
     *    @param data abi.encodePacked(address validationModule, bytes signatures)
     */
    function isValidSignature(
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        returns (bytes4 magicValue)
    {
        ISafe safe = ISafe(msg.sender);

        // check for safe's approved hashes
        if (data.length == 0 && safe.signedMessages(hash) != 0) {
            // return magic value
            return IERC1271.isValidSignature.selector;
        }
        address validationModule = address(bytes20(data[:20]));

        if (validationModule == address(0) || !_isValidatorInstalled(validationModule)) {
            bytes memory messageData = EIP712.encodeMessageData(
                safe.domainSeparator(), SAFE_MSG_TYPEHASH, abi.encode(keccak256(abi.encode(hash)))
            );

            bytes32 messageHash = keccak256(messageData);

            safe.checkSignatures(messageHash, messageData, data[20:]);
            return IERC1271.isValidSignature.selector;
        }

        // use 7579 validation module
        magicValue =
            IValidator(validationModule).isValidSignatureWithSender(msg.sender, hash, data[20:]);
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function installModule(
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        external
        payable
        override
        onlyEntryPointOrSelf
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) _installValidator(module, initData);
        else if (moduleType == MODULE_TYPE_EXECUTOR) _installExecutor(module, initData);
        else if (moduleType == MODULE_TYPE_FALLBACK) _installFallbackHandler(module, initData);
        else if (moduleType == MODULE_TYPE_HOOK) _installHook(module, initData);
        else revert UnsupportedModuleType(moduleType);
        emit ModuleInstalled(moduleType, module);
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function uninstallModule(
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        external
        payable
        override
        onlyEntryPointOrSelf
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) _uninstallValidator(module, deInitData);
        else if (moduleType == MODULE_TYPE_EXECUTOR) _uninstallExecutor(module, deInitData);
        else if (moduleType == MODULE_TYPE_FALLBACK) _uninstallFallbackHandler(module, deInitData);
        else if (moduleType == MODULE_TYPE_HOOK) _uninstallHook(module, deInitData);
        else revert UnsupportedModuleType(moduleType);
        emit ModuleUninstalled(moduleType, module);
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function supportsExecutionMode(ModeCode encodedMode) external pure override returns (bool) {
        CallType callType = encodedMode.getCallType();
        if (callType == CALLTYPE_BATCH) return true;
        else if (callType == CALLTYPE_SINGLE) return true;
        else if (callType == CALLTYPE_DELEGATECALL) return true;
        else return false;
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function supportsModule(uint256 moduleTypeId) external pure override returns (bool) {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) return true;
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR) return true;
        else if (moduleTypeId == MODULE_TYPE_FALLBACK) return true;
        else if (moduleTypeId == MODULE_TYPE_HOOK) return true;
        else return false;
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function isModuleInstalled(
        uint256 moduleType,
        address module,
        bytes calldata additionalContext
    )
        external
        view
        override
        returns (bool)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return _isValidatorInstalled(module);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return _isExecutorInstalled(module);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return _isFallbackHandlerInstalled(module, additionalContext);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return _isHookInstalled(module);
        } else {
            return false;
        }
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function accountId() external view override returns (string memory accountImplementationId) {
        string memory safeVersion = ISafe(_msgSender()).VERSION();
        return string(abi.encodePacked(safeVersion, "erc7579.v0.0.0"));
    }

    /**
     * @dev Decodes an ERC-4337 user operation into a Safe operation.
     * @param userOp The ERC-4337 user operation.
     * @return operationData Encoded EIP-712 Safe operation data bytes used for signature
     * verification.
     * @return validAfter The timestamp the user operation is valid from.
     * @return validUntil The timestamp the user operation is valid until.
     * @return signatures The Safe owner signatures extracted from the user operation.
     */
    function _getSafeOp(PackedUserOperation calldata userOp)
        internal
        view
        returns (
            bytes memory operationData,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signatures
        )
    {
        // Extract additional Safe operation fields from the user operation signature which is
        // encoded as:
        // `abi.encodePacked(validAfter, validUntil, signatures)`
        {
            bytes calldata sig = userOp.signature;
            validAfter = uint48(bytes6(sig[0:6]));
            validUntil = uint48(bytes6(sig[6:12]));
            signatures = sig[12:];
        }

        // It is important that **all** user operation fields are represented in the `SafeOp` data
        // somehow, to prevent
        // user operations from being submitted that do not fully respect the user preferences. The
        // only exception is
        // the `signature` bytes. Note that even `initCode` needs to be represented in the operation
        // data, otherwise
        // it can be replaced with a more expensive initialization that would charge the user
        // additional fees.
        {
            // In order to work around Solidity "stack too deep" errors related to too many stack
            // variables, manually
            // encode the `SafeOp` fields into a memory `struct` for computing the EIP-712
            // struct-hash. This works
            // because the `EncodedSafeOpStruct` struct has no "dynamic" fields so its memory layout
            // is identical to the
            // result of `abi.encode`-ing the individual fields.
            EncodedSafeOpStruct memory encodedSafeOp = EncodedSafeOpStruct({
                typeHash: SAFE_OP_TYPEHASH,
                safe: userOp.sender,
                nonce: userOp.nonce,
                initCodeHash: keccak256(userOp.initCode),
                callDataHash: keccak256(userOp.callData),
                callGasLimit: userOp.unpackCallGasLimit(),
                verificationGasLimit: userOp.unpackVerificationGasLimit(),
                preVerificationGas: userOp.preVerificationGas,
                maxFeePerGas: userOp.unpackMaxFeePerGas(),
                maxPriorityFeePerGas: userOp.unpackMaxPriorityFeePerGas(),
                paymasterAndDataHash: keccak256(userOp.paymasterAndData),
                validAfter: validAfter,
                validUntil: validUntil,
                entryPoint: entryPoint()
            });

            bytes32 safeOpStructHash;
            // solhint-disable-next-line no-inline-assembly
            assembly ("memory-safe") {
                // Since the `encodedSafeOp` value's memory layout is identical to the result of
                // `abi.encode`-ing the
                // individual `SafeOp` fields, we can pass it directly to `keccak256`. Additionally,
                // there are 14
                // 32-byte fields to hash, for a length of `14 * 32 = 448` bytes.
                safeOpStructHash := keccak256(encodedSafeOp, 448)
            }

            operationData =
                abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), safeOpStructHash);
        }
    }

    /**
     * Domain Separator for EIP-712.
     */
    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, this));
    }

    function initializeAccount(bytes calldata callData) external payable override {
        // TODO: destructuring callData
    }

    function initializeAccount(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit[] calldata hooks
    )
        public
        payable
        override
    {
        _initModuleManager();

        uint256 length = validators.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata validator = validators[i];
            _installValidator(validator.module, validator.initData);
        }

        length = executors.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata executor = executors[i];
            _installExecutor(executor.module, executor.initData);
        }

        length = fallbacks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata fallBack = fallbacks[i];
            _installFallbackHandler(fallBack.module, fallBack.initData);
        }

        length = hooks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata hook = hooks[i];
            _installFallbackHandler(hook.module, hook.initData);
        }

        emit Safe7579Initialized(msg.sender);
    }

    /**
     * Safe7579 is using validator selection encoding in the userop nonce.
     * to make it easier for SDKs / devs to integrate, this function can be
     * called to get the next nonce for a specific validator
     */
    function getNonce(address safe, address validator) external view returns (uint256 nonce) {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = IEntryPoint(entryPoint()).getNonce(safe, key);
    }
}

library EIP712 {
    function encodeMessageData(
        bytes32 domainSeparator,
        bytes32 typeHash,
        bytes memory message
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes1(0x19),
            bytes1(0x01),
            domainSeparator,
            keccak256(abi.encodePacked(typeHash, message))
        );
    }
}
