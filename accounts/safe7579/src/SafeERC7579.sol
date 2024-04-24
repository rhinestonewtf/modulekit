// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account, Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { IMSA } from "erc7579/interfaces/IMSA.sol";
import {
    CallType, ModeCode, ModeLib, CALLTYPE_SINGLE, CALLTYPE_BATCH
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

/**
 * @title ERC7579 Adapter for Safe accounts.
 * By using Safe's Fallback and Execution modules,
 * this contract creates full ERC7579 compliance to Safe accounts
 * @author zeroknots.eth | rhinestone.wtf
 */
contract SafeERC7579 is ISafeOp, IERC7579Account, AccessControl, IMSA, HookManager {
    using UserOperationLib for PackedUserOperation;
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    error Unsupported();

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

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
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    function executeUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        payable
        onlyEntryPointOrSelf
    {
        (bool success,) = address(this).delegatecall(userOp.callData[4:]);
        if (!success) revert ExecutionFailed();
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        returns (uint256 validSignature)
    {
        address validator;
        uint256 nonce = userOp.nonce;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            validator := shr(96, nonce)
        }

        // check if validator is enabled. If not, use Safe's checkSignatures()
        if (!_isValidatorInstalled(validator)) return _validateSignatures(userOp);

        // bubble up the return value of the validator module
        bytes memory retData = _executeReturnData({
            safe: msg.sender,
            target: validator,
            value: 0,
            callData: abi.encodeCall(IValidator.validateUserOp, (userOp, userOpHash))
        });
        validSignature = abi.decode(retData, (uint256));

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
     * @inheritdoc IERC7579Account
     */
    function isValidSignature(bytes32 hash, bytes calldata data) external view returns (bytes4) { }

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
        bytes calldata /*additionalContext*/
    )
        external
        view
        override
        returns (bool)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) return _isValidatorInstalled(module);
        else if (moduleType == MODULE_TYPE_EXECUTOR) return _isExecutorInstalled(module);
        else if (moduleType == MODULE_TYPE_FALLBACK) return _isFallbackHandlerInstalled(module);
        else if (moduleType == MODULE_TYPE_HOOK) return _isHookInstalled(module);
        else return false;
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function accountId() external view override returns (string memory accountImplementationId) {
        string memory version = ISafe(msg.sender).VERSION();

        accountImplementationId =
            string(abi.encodePacked("safe", abi.encodePacked(version), ".erc7579.v0.0.1"));
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

    function initializeAccount(bytes calldata data) external payable {
        _initModuleManager();

        (address bootstrap, bytes memory bootstrapCall) = abi.decode(data, (address, bytes));

        (bool success,) = bootstrap.delegatecall(bootstrapCall);
        if (!success) revert AccountInitializationFailed();
    }
}
