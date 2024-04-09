// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IAccount, PackedUserOperation } from "account-abstraction/interfaces/IAccount.sol";
import {
    _packValidationData,
    _parseValidationData,
    ValidationData
} from "account-abstraction/core/Helpers.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { IUniqueSignerFactory } from "./SignerFactory.sol";
import { ISafe7579Init } from "../interfaces/ISafe7579Init.sol";
import { IERC7484 } from "../interfaces/IERC7484.sol";
import { SafeERC7579 } from "../SafeERC7579.sol";

import { IValidator } from "erc7579/interfaces/IERC7579Module.sol";

import { SafeStorage } from "@safe-global/safe-contracts/contracts/libraries/SafeStorage.sol";
import { ISignatureValidator } from
    "@safe-global/safe-contracts/contracts/interfaces/ISignatureValidator.sol";

import "forge-std/console2.sol";

/**
 * @title SafeOpLaunchpad - A contract for Safe initialization with custom unique signers that would
 * violate ERC-4337 factory rules.
 * @dev The is intended to be set as a Safe proxy's implementation for ERC-4337 user operation that
 * deploys the account.
 */
contract SafeSignerLaunchpad is IAccount, SafeStorage {
    struct InitData {
        address singleton;
        address[] owners;
        uint256 threshold;
        address setupTo;
        bytes setupData;
        address safeFallbackHandler;
        bytes callData;
    }

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

    // keccak256("SafeSignerLaunchpad.initHash") - 1
    uint256 private constant INIT_HASH_SLOT =
        0x1d2f0b9dbb6ed3f829c9614e6c5d2ea2285238801394dc57e8500e0e306d8f80;

    /**
     * @notice The keccak256 hash of the EIP-712 SafeInit struct, representing the structure of a
     * ERC-4337 compatible deferred Safe initialization.
     *  {address} singleton - The singleton to evolve into during the setup.
     *  {address} signerFactory - The unique signer factory to use for creating an owner.
     *  {bytes} signerData - The signer data to use the owner.
     *  {address} setupTo - The contract to delegatecall during setup.
     *  {bytes} setupData - The calldata for the setup delegatecall.
     *  {address} fallbackHandler - The fallback handler to initialize the Safe with.
     */
    bytes32 private constant SAFE_INIT_TYPEHASH = keccak256(
        "SafeInit(address singleton,address signerFactory,bytes signerData,address setupTo,bytes setupData,address fallbackHandler)"
    );

    /**
     * @notice The keccak256 hash of the EIP-712 SafeInitOp struct, representing the user operation
     * to execute alongside initialization.
     *  {bytes32} userOpHash - The user operation hash being executed.
     *  {uint48} validAfter - A timestamp representing from when the user operation is valid.
     *  {uint48} validUntil - A timestamp representing until when the user operation is valid, or 0
     * to indicated "forever".
     *  {address} entryPoint - The address of the entry point that will execute the user operation.
     */
    bytes32 private constant SAFE_INIT_OP_TYPEHASH = keccak256(
        "SafeInitOp(bytes32 userOpHash,uint48 validAfter,uint48 validUntil,address entryPoint)"
    );

    address private immutable SELF;
    address public immutable SUPPORTED_ENTRYPOINT;
    IERC7484 public immutable REGISTRY;

    constructor(address entryPoint, IERC7484 registry) {
        require(entryPoint != address(0), "Invalid entry point");

        SELF = address(this);
        SUPPORTED_ENTRYPOINT = entryPoint;
        REGISTRY = registry;
    }

    function initSafe7579WithRegistry(
        address safe7579,
        ISafe7579Init.ModuleInit[] calldata validators,
        ISafe7579Init.ModuleInit[] calldata executors,
        ISafe7579Init.ModuleInit[] calldata fallbacks,
        ISafe7579Init.ModuleInit calldata hook,
        address[] calldata attesters,
        uint8 threshold
    )
        public
    {
        ISafe(address(this)).enableModule(safe7579);
        SafeERC7579(payable(safe7579)).initializeAccountWithRegistry(
            validators,
            executors,
            fallbacks,
            hook,
            ISafe7579Init.RegistryInit({
                registry: REGISTRY,
                attesters: attesters,
                threshold: threshold
            })
        );
    }

    function initSafe7579(
        address safe7579,
        ISafe7579Init.ModuleInit[] calldata validators,
        ISafe7579Init.ModuleInit[] calldata executors,
        ISafe7579Init.ModuleInit[] calldata fallbacks,
        ISafe7579Init.ModuleInit calldata hook
    )
        public
    {
        ISafe(address(this)).enableModule(safe7579);
        SafeERC7579(payable(safe7579)).initializeAccount(validators, executors, fallbacks, hook);
    }

    modifier onlyProxy() {
        require(singleton == SELF, "Not called from proxy");
        _;
    }

    modifier onlySupportedEntryPoint() {
        require(msg.sender == SUPPORTED_ENTRYPOINT, "Unsupported entry point");
        _;
    }

    receive() external payable { }

    function preValidationSetup(
        bytes32 initHash,
        address to,
        bytes calldata preInit
    )
        external
        onlyProxy
    {
        _setInitHash(initHash);
        console2.log("this", address(this));
        if (to != address(0)) {
            (bool success,) = to.delegatecall(preInit);
            require(success, "Pre-initialization failed");
        }
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        override
        onlyProxy
        onlySupportedEntryPoint
        returns (uint256 validationData)
    {
        require(
            this.executeUserOp.selector == bytes4(userOp.callData[:4]),
            "invalid user operation data"
        );

        InitData memory initData = abi.decode(userOp.callData[4:], (InitData));

        require(hash(initData) == _initHash(), "invalid init hash");

        // TODO: is it a problem that we dont validate the signature with the validator here?

        if (missingAccountFunds > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly ("memory-safe") {
                pop(call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0))
            }
        }
    }

    function executeUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        onlySupportedEntryPoint
    {
        InitData memory initData = abi.decode(userOp.callData[4:], (InitData));
        // update singleton to Safe account impl
        SafeStorage.singleton = initData.singleton;

        ISafe(address(this)).setup(
            initData.owners,
            initData.threshold,
            initData.setupTo,
            initData.setupData,
            initData.safeFallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        (bool success, bytes memory returnData) = address(this).delegatecall(initData.callData);
        if (!success) {
            // solhint-disable-next-line no-inline-assembly
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }

        _setInitHash(0);

        // validate user operation
        address validator;
        uint256 nonce = userOp.nonce;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            validator := shr(96, nonce)
        }

        uint256 ret = IValidator(validator).validateUserOp(userOp, userOpHash);
        // TODO: unpack properly
        // consider comparing validUntil/validAfter to userOp.signature
        if (ret != 0) revert();
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, SELF));
    }

    function _getOperationData(
        bytes32 userOpHash,
        uint48 validAfter,
        uint48 validUntil
    )
        public
        view
        returns (bytes memory operationData)
    {
        operationData = abi.encodePacked(
            bytes1(0x19),
            bytes1(0x01),
            _domainSeparator(),
            keccak256(
                abi.encode(
                    SAFE_INIT_OP_TYPEHASH, userOpHash, validAfter, validUntil, SUPPORTED_ENTRYPOINT
                )
            )
        );
    }

    function _initHash() public view returns (bytes32 value) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            value := sload(INIT_HASH_SLOT)
        }
    }

    function _setInitHash(bytes32 value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            sstore(INIT_HASH_SLOT, value)
        }
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            size := extcodesize(account)
        }
        /* solhint-enable no-inline-assembly */
        return size > 0;
    }

    function getOperationHash(
        bytes32 userOpHash,
        uint48 validAfter,
        uint48 validUntil
    )
        public
        view
        returns (bytes32 operationHash)
    {
        operationHash = keccak256(_getOperationData(userOpHash, validAfter, validUntil));
    }

    function predictSafeAddress(
        address singleton,
        address safeProxyFactory,
        bytes memory creationCode,
        bytes32 salt,
        bytes memory factoryInitializer
    )
        external
        pure
        returns (address safeProxy)
    {
        salt = keccak256(abi.encodePacked(keccak256(factoryInitializer), salt));

        safeProxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(safeProxyFactory),
                            salt,
                            keccak256(
                                abi.encodePacked(creationCode, uint256(uint160(address(singleton))))
                            )
                        )
                    )
                )
            )
        );
    }

    function hash(InitData memory data) public returns (bytes32) {
        return keccak256(abi.encode(data));
    }
}