// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { WebAuthnLib } from "./utils/WebAuthNLib.sol";
import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";
import {
    PackedUserOperation, UserOperationLib
} from "@rhinestone/modulekit/src/external/ERC4337.sol";
import { WebAuthnFclVerifier } from "./WebAuthnFclVerifier.sol";

struct PassKeyId {
    uint256 pubKeyX;
    uint256 pubKeyY;
    string keyId;
}
/// @author @KONFeature
/// @author @KONFeature
/// @title WebAuthnFclValidator
/// @notice ModuleKit validator used to validated user operations via WebAuthn signature (using P256
/// under the hood), and compatible with RIP-7212 signature validation (so really low gas cost
/// consumption for compliant chains)
/// @notice Using the awesome FreshCryptoLib: https://github.com/rdubois-crypto/FreshCryptoLib/
/// @notice Inspired by the cometh Gnosis Safe signer: https://github.com/cometh-game/p256-signer
/// @notice To work with chain not supporting RIP-7212, the constructor take as param a wrapped
/// P256Verifier contract, a contract like `./utils/P256VerifierWrapper.sol` can be used for that
contract WebAuthnValidator7212 is ERC7579ValidatorBase {
    using UserOperationLib for PackedUserOperation;

    /// @dev Error emitted when no passkey is registered for a smart account
    error NoPassKeyRegisteredForSmartAccount(address smartAccount);

    /// @dev Event emitted when a new passkey is registered for a smart account
    event NewPassKeyRegistered(address indexed smartAccount, string keyId);

    /// @dev Mapping of smart accounts to their passkey configuration
    mapping(address account => PassKeyId passkeyConfig) public smartAccountPassKeys;

    /// @dev The address of the on-chain p256 verifier contract
    ///   (will be used if the user want that instead of the pre-compiled one, that way this
    /// validator can work on every chain out of the box while rip7212 is slowly being implemented
    /// everywhere)
    address private immutable P256_VERIFIER;

    /// @dev Simple constructor, setting the P256 verifier address
    constructor(address _p256Verifier) {
        P256_VERIFIER = _p256Verifier;
    }

    /// @notice Registers a new passkey, encoded in the `data`, for the calling smart account
    function onInstall(bytes calldata _data) external override {
        PassKeyId memory passkey = abi.decode(_data, (PassKeyId));
        smartAccountPassKeys[msg.sender] = passkey;
    }

    /// @notice Removes the passkey for the calling smart account
    function onUninstall(bytes calldata) external override {
        delete smartAccountPassKeys[msg.sender];
    }

    /// @notice Returns the passkey configuration for the given `account`
    function getAuthorizedKey(address _account) external view returns (PassKeyId memory passkey) {
        passkey = smartAccountPassKeys[_account];
    }

    /// @dev Validate the given `userOp` with the given `userOpHash`
    function validateUserOp(
        PackedUserOperation calldata _userOp,
        bytes32 _userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        address sender = _userOp.getSender();
        PassKeyId storage passKey = smartAccountPassKeys[sender];
        if (passKey.pubKeyX == 0 || passKey.pubKeyY == 0) {
            revert NoPassKeyRegisteredForSmartAccount(sender);
        }

        // Validate the user op signature
        bool isValidSignature = _checkSignature(passKey, _userOpHash, _userOp.signature);

        // Pack the validation data
        return _packValidationData(!isValidSignature, 0, type(uint48).max);
    }

    /// @dev Validate the given `signature` for the `_sender` on the given `_hash`
    function isValidSignatureWithSender(
        address _sender,
        bytes32 _hash,
        bytes calldata _signature
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        bool isValidSignature = _checkSignature(smartAccountPassKeys[_sender], _hash, _signature);
        return isValidSignature ? EIP1271_SUCCESS : EIP1271_FAILED;
    }

    /// @notice Validates the given `_signature` againt the `_hash` for the given `kernel`
    /// (msg.sender)
    /// @param _passKeyStorage The passkey module related storage (helping us to fetch the X & Y
    /// points of the public key)
    /// @param _hash The hash signed
    /// @param _signature The signature
    function _checkSignature(
        PassKeyId memory _passKeyStorage,
        bytes32 _hash,
        bytes calldata _signature
    )
        private
        view
        returns (bool isValid)
    {
        // Extract the first byte of the signature to check
        return WebAuthnFclVerifier._verifyWebAuthNSignature(
            P256_VERIFIER, _hash, _signature, _passKeyStorage.pubKeyX, _passKeyStorage.pubKeyY
        );
    }

    /// @dev Packs the validation data into a `ValidationData` struct
    function name() external pure returns (string memory) {
        return "WebAuthnValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
