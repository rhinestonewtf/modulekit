import "@rhinestone/modulekit/src/Modules.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";
import "forge-std/console2.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import "../DataTypes.sol";
import "../interfaces/ILicenseManager.sol";

abstract contract LicenseSignerBase is ERC7579ValidatorBase {
    struct SignerConf {
        bool autoPermitEnabled;
        uint256 foo;
    }

    ILicenseManager immutable LICENSE_MANAGER;
    bytes32 immutable LICENSE_MANAGER_DOMAIN_SEPARATOR;
    address immutable PERMIT2;
    bytes32 immutable PERMIT2_DOMAIN_SEPARATOR;

    error UnauthorizedERC1271Request();

    mapping(address smartAccount => mapping(address module => SignerConf)) internal _signer;

    constructor(address permit2, address licenseManager) {
        PERMIT2 = permit2;
        PERMIT2_DOMAIN_SEPARATOR = IPermit2(permit2).DOMAIN_SEPARATOR();
        LICENSE_MANAGER = ILicenseManager(licenseManager);
        LICENSE_MANAGER_DOMAIN_SEPARATOR = LICENSE_MANAGER.domainSeparator();
    }

    modifier onlyPermit2(address sender) {
        if (sender != PERMIT2) revert UnauthorizedERC1271Request();
        _;
    }

    function validateUserOp(
        PackedUserOperation calldata, /*userOp*/
        bytes32 /*userOpHash*/
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        return VALIDATION_FAILED;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4);
}

library EIP712Signer {
    function hashTypedData(
        bytes32 domainSeparator,
        bytes32 structHash
    )
        internal
        pure
        returns (bytes32 digest)
    {
        // We will use `digest` to store the domain separator to save a bit of gas.
        digest = domainSeparator;
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    /**
     * copied from Permti PermitHash.sol, because function in lib is using calldata
     */
    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address permitSender,
        bytes32 witness,
        string memory witnessTypeString
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 typeHash = keccak256(
            abi.encodePacked(
                PermitHash._PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeString
            )
        );

        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(
                typeHash, tokenPermissionsHash, permitSender, permit.nonce, permit.deadline, witness
            )
        );
    }

    /**
     * copied from Permit PermitHash.sol, because function in lib is private
     */
    function _hashTokenPermissions(ISignatureTransfer.TokenPermissions memory permitted)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }
}
