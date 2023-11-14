pragma solidity ^0.8.21;

/**
 *             .+#%@@@#+:
 *            -%@@@*++*@@@%=
 *         -%@@#-      :*@@@=            @author:     zeroknots.eth, Konrad Kopp (@kopy-kat)
 *       -%@@#:    :-    .*@@@=          @license:    SPDX-License-Identifier: MIT
 *     -%@@#:     .@@:     .*@@%-        @title:      Rhinestone4337
 *     @@%:      :%@@@-      :#@@#                    Abstract contract to handle user operations in the context of EIP-4337. Extends the functionality of
 *    @@*     .-#@@@@@@%=.     +@@#                   FallbackHandler, RegistryAdapterForSingletons to ensure secure and efficient handling of user operations.
 *   @@@    +@@@@@@@@@@@@@@*    @@@                   Provides an interface for working with EIP-1271 signature validation and EIP-7484 validators.
 *    @@+     .=%@@@@@@%=:     =@@      @dev this is a modified mock contract to add ERC-4337 to Safe accounts.
 *     @@#:      -@@@@-      .#@@       @dev this contract MUST NOT be used in production.
 *     -@@@*.     .@@:     .*@@@
 *       =@@@*.    --    .*@@@+
 *         =%@@#:      :*@@@=
 *           =%@@%*==+%@@%=
 *             :+#@@@@%+:
 */

import { IERC7484Registry, RegistryAdapterForSingletons } from "../common/IERC7484Registry.sol";
import "../common/IERC1271.sol";
import { UserOperation } from "../common/erc4337/UserOperation.sol";
import { SentinelListLib } from "sentinellist/src/SentinelList.sol";
import { IValidator } from "../modulekit/interfaces/IValidator.sol";
import "../common/ERC2771Context.sol";
import { ExecutorAction } from "../modulekit/interfaces/IExecutor.sol";
import "../modulekit/lib/ValidatorSelectionLib.sol";
import "../common/FallbackHandler.sol";

abstract contract Rhinestone4337 is RegistryAdapterForSingletons, FallbackHandler {
    using SentinelListLib for SentinelListLib.SentinelList;
    using ValidatorSelectionLib for UserOperation;

    // Type hashes for EIP-712 domain and the safe operations.
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant SAFE_OP_TYPEHASH = keccak256(
        "SafeOp(address safe,bytes callData,uint256 nonce,uint256 verificationGas,uint256 preVerificationGas,uint256 maxFeePerGas,uint256 maxPriorityFeePerGas,uint256 callGas,address entryPoint)"
    );

    // Address of the entry point that is supported.
    address public immutable supportedEntryPoint;

    // Struct to track execution status for operations.
    struct ExecutionStatus {
        bool approved;
        bool executed;
    }

    mapping(address account => mapping(bytes32 => ExecutionStatus)) private _hashes;
    mapping(address account => SentinelListLib.SentinelList validators) internal validators;

    event ValidatorAdded(address indexed account, address indexed validator);
    event ValidatorRemoved(address indexed account, address indexed validator);

    /**
     * @dev Constructor that initializes the supported entry point and sets the registry.
     * @param _entryPoint - The address of the supported entry point.
     * @param _registry - The registry for ERC-7484.
     */
    constructor(
        address _entryPoint,
        IERC7484Registry _registry
    )
        RegistryAdapterForSingletons(_registry)
    {
        supportedEntryPoint = _entryPoint;
    }

    /**
     * Initializes the contract by setting the validator.
     * @dev make sure init() is called before adding validators
     * @param validator - Address of the validator.
     * @param trustedAttester - Address of the trusted attester for ERC-7484
     */
    function init(address validator, address trustedAttester) external {
        _setAttester(msg.sender, trustedAttester);
        validators[msg.sender].init();
        validators[msg.sender].push(validator);
        emit ValidatorAdded(msg.sender, validator);
    }

    /**
     * Adds a validator.
     * @dev queries the registry with ERC-7484 to ensure that the validator is trusted.
     * @param validator - Address of the validator to be added.
     */
    function addValidator(address validator) external onlySecureModule(validator) {
        validators[msg.sender].push(validator);
        emit ValidatorAdded(msg.sender, validator);
    }

    /**
     * @dev Removes a validator.
     * @param prevValidator - Address of the previous validator in the list.
     * @param delValidator - Address of the validator to be removed.
     */
    function removeValidator(address prevValidator, address delValidator) external {
        validators[msg.sender].pop({ prevEntry: prevValidator, popEntry: delValidator });

        emit ValidatorRemoved(msg.sender, delValidator);
    }

    /**
     * @dev Returns paginated list of validators.
     * @param start - Starting address for the pagination.
     * @param pageSize - Number of entries per page.
     * @param account - Account whose validators are to be fetched.
     */
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

    /**
     * @dev Checks if a validator is enabled for an account.
     * @param account - Address of the account.
     * @param validator - Address of the validator.
     */
    function isValidatorEnabled(address account, address validator) public view returns (bool) {
        return validators[account].contains(validator);
    }

    /**
     * @dev Validates a user operation provided by the entry point.
     * @param userOp - User operation details.
     * @param userOpHash - Hash of the user operation.
     * @param requiredPrefund - Prefund required to execute the operation.
     */
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
        // get validators for target
        address validator;
        uint256 sigLength = userOp.signature.length;

        validator = userOp.decodeValidator();

        // check if selected validator is enabled
        require(isValidatorEnabled(userOp.sender, validator), "Validator not enabled");

        uint256 isValid = IValidator(validator).validateUserOp(userOp, userOpHash);
        require(isValid == 0, "Invalid signature");
    }

    function executeBatch(ExecutorAction[] calldata action) external payable {
        // TODO
        uint256 len = action.length;
        for (uint256 i; i < len; i++) {
            _execTransationOnSmartAccount(msg.sender, action[i].to, action[i].value, action[i].data);
        }
    }

    function execute(ExecutorAction calldata action) external payable {
        // TODO
        _execTransationOnSmartAccount(msg.sender, action.to, action.value, action.data);
    }

    /**
     * @dev Validates the signature using EIP-1271 standard.
     * @param dataHash - Hash of the data to be signed.
     * @param signature - Signature data.
     */
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

        require(isValidatorEnabled(msg.sender, validationModule), "Validator not enabled");
        return IERC1271(validationModule).isValidSignature(dataHash, moduleSignature);
    }

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
