// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import "@aa/interfaces/UserOperation.sol";

import {IValidatorModule} from "../../modules/validators/IValidatorModule.sol";

import {RhinestoneAdmin} from "./RhinestoneAdmin.sol";
import {SelectValidatorLib} from "../lib/SelectValidatorLib.sol";

abstract contract Rhinestone4337 is RhinestoneAdmin {
    using SelectValidatorLib for UserOperation;

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

    bytes32 private constant SAFE_OP_TYPEHASH = keccak256(
        "SafeOp(address safe,bytes callData,uint256 nonce,uint256 verificationGas,uint256 preVerificationGas,uint256 maxFeePerGas,uint256 maxPriorityFeePerGas,uint256 callGas,address entryPoint)"
    );

    address public immutable supportedEntryPoint;

    event NewRhinestoneManager(address addressThis);

    struct ExecutionStatus {
        bool approved;
        bool executed;
    }

    mapping(bytes32 => ExecutionStatus) private hashes;

    constructor(address entryPoint, address registry, address trustedAuthority) {
        supportedEntryPoint = entryPoint;
        _setRegistry(registry);
        emit NewRhinestoneManager(address(this));
    }

    /// @dev Validates user operation provided by the entry point
    /// @param userOp User operation struct
    /// @param requiredPrefund Required prefund to execute the operation
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPrefund)
        external
        returns (uint256)
    {
        address payable safeAddress = payable(userOp.sender);

        // The entryPoint address is appended to the calldata in `HandlerContext` contract
        // Because of this, the relayer may be manipulate the entryPoint address, therefore we have to verify that
        // the sender is the Safe specified in the userOperation
        require(safeAddress == msg.sender, "Invalid Caller");
        validateReplayProtection(userOp);

        // get entrypoint from params
        address entryPoint = _msgSender();
        // enforce that only trusted entrypoint can be used
        require(entryPoint == supportedEntryPoint, "Unsupported entry point");

        // TODO verify return
        _validateSignatures(userOp, userOpHash);

        if (requiredPrefund != 0) {
            _prefundEntrypoint(safeAddress, entryPoint, requiredPrefund);
        }
        return 0;
    }

    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param safe Safe address
    /// @param callData Call data
    /// @param nonce Nonce of the operation
    /// @param verificationGas Gas required for verification
    /// @param preVerificationGas Gas required for pre-verification (e.g. for EOA signature verification)
    /// @param maxFeePerGas Max fee per gas
    /// @param maxPriorityFeePerGas Max priority fee per gas
    /// @param callGas Gas available during the execution of the call
    /// @param entryPoint Address of the entry point
    /// @return Operation hash bytes
    function encodeOperationData(
        address safe,
        bytes calldata callData,
        uint256 nonce,
        uint256 verificationGas,
        uint256 preVerificationGas,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 callGas,
        address entryPoint
    ) public view returns (bytes memory) {
        bytes32 safeOperationHash = keccak256(
            abi.encode(
                SAFE_OP_TYPEHASH,
                safe,
                keccak256(callData),
                nonce,
                verificationGas,
                preVerificationGas,
                maxFeePerGas,
                maxPriorityFeePerGas,
                callGas,
                entryPoint
            )
        );

        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), safeOperationHash);
    }

    function _validateSignatures(UserOperation calldata userOp, bytes32 userOpHash) internal {
        // get operation target from userOp
        // (, address target,,,,) =
        //     abi.decode(userOp.callData[4:], (address, address, uint256, bytes, uint8, uint256));

        // get validators for target
        address validator;
        uint256 sigLength = userOp.signature.length;

        if (sigLength == 0) return;
        else validator = userOp.decodeValidator();

        // check if selected validator is enabled
        require(isEnabledValidator(validator), "Validator not enabled");

        uint256 ret = IValidatorModule(validator).validateUserOp(userOp, userOpHash);
        require(ret == 0, "Invalid signature");
    }

    function checkAndExecTransactionFromModule(
        address smartAccount,
        address target,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 nonce
    ) external {
        bytes32 executionHash = keccak256(abi.encode(smartAccount, target, value, data, operation, nonce));
        ExecutionStatus memory status = hashes[executionHash];
        require(status.approved && !status.executed, "Unexpected status");
        hashes[executionHash].executed = true;

        // check if target is an installed executor

        // if (isExecutorEnabled(target)) {
        //     _execExecutor(target, value, data);
        // } else {
        _execTransationOnSmartAccount(smartAccount, target, value, data);
        // }
    }

    function validateReplayProtection(UserOperation calldata userOp) internal {
        bytes32 executionHash = keccak256(userOp.callData[4:]);
        ExecutionStatus memory status = hashes[executionHash];
        require(!status.approved && !status.executed, "Unexpected status");
        hashes[executionHash].approved = true;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, this));
    }

    function _prefundEntrypoint(address safe, address entryPoint, uint256 requiredPrefund) internal virtual;

    function _execTransationOnSmartAccount(address account, address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);
}
