// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7484Registry, RegistryAdapterForSingletons } from "../common/IERC7484Registry.sol";
import "../common/IERC1271.sol";
import "../common/erc4337/UserOperation.sol";
import { SentinelListLib } from "sentinellist/src/SentinelList.sol";
import "../modulekit/IValidator.sol";
import "../common/ERC2771Context.sol";
import "../modulekit/lib/ValidatorSelectionLib.sol";

abstract contract Rhinestone4337 is RegistryAdapterForSingletons, ERC2771Context {
    using SentinelListLib for SentinelListLib.SentinelList;
    using ValidatorSelectionLib for UserOperation;

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

    bytes32 private constant SAFE_OP_TYPEHASH = keccak256(
        "SafeOp(address safe,bytes callData,uint256 nonce,uint256 verificationGas,uint256 preVerificationGas,uint256 maxFeePerGas,uint256 maxPriorityFeePerGas,uint256 callGas,address entryPoint)"
    );

    address public immutable supportedEntryPoint;

    struct ExecutionStatus {
        bool approved;
        bool executed;
    }

    mapping(address account => mapping(bytes32 => ExecutionStatus)) private _hashes;

    mapping(address account => SentinelListLib.SentinelList validators) internal validators;

    event ValidatorAdded(address indexed account, address indexed validator);
    event ValidatorRemoved(address indexed account, address indexed validator);

    constructor(
        address _entryPoint,
        IERC7484Registry _registry
    )
        RegistryAdapterForSingletons(_registry)
    {
        supportedEntryPoint = _entryPoint;
    }

    function init(address validator) external {
        validators[msg.sender].init();
        validators[msg.sender].push(validator);
        emit ValidatorAdded(msg.sender, validator);
    }

    function addValidator(address validator) external onlySmartAccount {
        validators[msg.sender].push(validator);
        emit ValidatorAdded(msg.sender, validator);
    }

    function removeValidator(
        address prevValidator,
        address delValidator
    )
        external
        onlySmartAccount
    {
        validators[msg.sender].pop({ prevEntry: prevValidator, popEntry: delValidator });

        emit ValidatorRemoved(msg.sender, delValidator);
    }

    function getValidatorPaginated(
        address start,
        uint256 pageSize,
        address account
    )
        external
        view
        returns (address[] memory array, address next)
    {
        return validators[account].getEntriesPaginated(start, pageSize);
    }

    function isEnabledValidator(address account, address validator) public view returns (bool) {
        return validators[account].contains(validator);
    }

    /// @dev Validates user operation provided by the entry point
    /// @param userOp User operation struct
    /// @param requiredPrefund Required prefund to execute the operation
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPrefund
    )
        external
        returns (uint256)
    {
        address payable safeAddress = payable(userOp.sender);

        // The entryPoint address is appended to the calldata in `HandlerContext` contract
        // Because of this, the relayer may be manipulate the entryPoint address, therefore we have to verify that
        // the sender is the Safe specified in the userOperation
        require(safeAddress == msg.sender, "Invalid Caller");
        // validateReplayProtection(userOp);

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
    )
        public
        view
        returns (bytes memory)
    {
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
        require(isEnabledValidator(userOp.sender, validator), "Validator not enabled");

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
    )
        external
    {
        bytes32 executionHash =
            keccak256(abi.encode(smartAccount, target, value, data, operation, nonce));
        ExecutionStatus memory status = _hashes[smartAccount][executionHash];
        // require(status.approved && !status.executed, "Unexpected status");
        _hashes[smartAccount][executionHash].executed = true;

        // check if target is an installed executor

        // if (isExecutorEnabled(target)) {
        //     _execExecutor(target, value, data);
        // } else {
        _execTransationOnSmartAccount(smartAccount, target, value, data);
        // }
    }

    function isValidSignature(
        bytes32 dataHash,
        bytes calldata signature
    )
        public
        view
        returns (bytes4)
    {
        (bytes memory moduleSignature, address validationModule) =
            abi.decode(signature, (bytes, address));

        require(isEnabledValidator(msg.sender, validationModule), "Validator not enabled");
        return IERC1271(validationModule).isValidSignature(dataHash, moduleSignature);
    }

    // function validateReplayProtection(UserOperation calldata userOp) internal {
    //     bytes32 executionHash = keccak256(userOp.callData[4:]);
    //     ExecutionStatus memory status = _hashes[executionHash];
    //     require(!status.approved && !status.executed, "Unexpected status");
    //     _hashes[executionHash].approved = true;
    // }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, this));
    }

    function _prefundEntrypoint(
        address safe,
        address entryPoint,
        uint256 requiredPrefund
    )
        internal
        virtual;

    function _execTransationOnSmartAccount(
        address account,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        virtual
        returns (bool, bytes memory);
}
