// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "erc7579/interfaces/IERC7579Account.sol";
import "erc7579/interfaces/IMSA.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/lib/ExecutionLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import "./AccessControl.sol";
import "./HookManager.sol";
import "./ExecutionHelper.sol";
import "./ModuleManager.sol";
import "./interfaces/ISafeOp.sol";
import { UserOperationLib } from "account-abstraction/core/UserOperationLib.sol";
import { _packValidationData } from "account-abstraction/core/Helpers.sol";

contract SafeERC7579 is
    ISafeOp,
    IERC7579Account,
    AccessControl,
    ExecutionHelper,
    IMSA,
    HookManager
{
    using UserOperationLib for PackedUserOperation;
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    function execute(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        override
        onlyEntryPointOrSelf
        withHook
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

    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        override
        onlyExecutorModule
        withHook
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

    function executeUserOp(PackedUserOperation calldata userOp)
        external
        payable
        override
        onlyEntryPointOrSelf
    { }

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
        assembly {
            validator := shr(96, nonce)
        }

        // check if validator is enabled. If terminate the validation phase.
        if (!_isValidatorInstalled(validator)) return _validateSignatures(userOp);

        // bubble up the return value of the validator module
        validSignature = IValidator(validator).validateUserOp(userOp, userOpHash);

        // pay prefund
        if (missingAccountFunds != 0) {
            ISafe(userOp.getSender()).execTransactionFromModule(
                entryPoint(), missingAccountFunds, "", 0
            );
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

    function isValidSignature(bytes32 hash, bytes calldata data) external view returns (bytes4) { }

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

    function supportsAccountMode(ModeCode encodedMode) external pure override returns (bool) {
        CallType callType = encodedMode.getCallType();
        if (callType == CALLTYPE_BATCH) return true;
        else if (callType == CALLTYPE_SINGLE) return true;
        else return false;
    }

    function supportsModule(uint256 moduleTypeId) external pure override returns (bool) {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) return true;
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR) return true;
        else if (moduleTypeId == MODULE_TYPE_FALLBACK) return true;
        else return false;
    }

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

    function accountId() external pure override returns (string memory accountImplementationId) {
        return "safe-erc7579.v0.0.1";
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

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, this));
    }

    function initializeAccount(bytes calldata data) external payable {
        _initModuleManager();
        (address[] memory validators, address[] memory executors) =
            abi.decode(data, (address[], address[]));
        for (uint256 i = 0; i < validators.length; i++) {
            _installValidator(validators[i], data);
        }

        for (uint256 i = 0; i < executors.length; i++) {
            _installExecutor(executors[i], data);
        }
    }
}
