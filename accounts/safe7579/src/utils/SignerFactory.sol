// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISignatureValidator } from
    "@safe-global/safe-contracts/contracts/interfaces/ISignatureValidator.sol";

interface IUniqueSignerFactory {
    /**
     * @notice Gets the unique signer address for the specified data.
     * @dev The unique signer address must be unique for some given data. The signer is not
     * guaranteed to be created yet.
     * @param data The signer specific data.
     * @return signer The signer address.
     */
    function getSigner(bytes memory data) external view returns (address signer);

    /**
     * @notice Create a new unique signer for the specified data.
     * @dev The unique signer address must be unique for some given data. This must not revert if
     * the unique owner already exists.
     * @param data The signer specific data.
     * @return signer The signer address.
     */
    function createSigner(bytes memory data) external returns (address signer);

    /**
     * @notice Verifies a signature for the specified address without deploying it.
     * @dev This must be equivalent to first deploying the signer with the factory, and then
     * verifying the signature
     * with it directly: `factory.createSigner(signerData).isValidSignature(data, signature)`
     * @param data The data whose signature should be verified.
     * @param signature The signature bytes.
     * @param signerData The signer data to verify signature for.
     * @return magicValue Returns `ISignatureValidator.isValidSignature.selector` when the signature
     * is valid. Reverting or returning any other value implies an invalid signature.
     */
    function isValidSignatureForSigner(
        bytes calldata data,
        bytes calldata signature,
        bytes calldata signerData
    )
        external
        view
        returns (bytes4 magicValue);
}

function checkSignature(
    bytes memory data,
    uint256 signature,
    uint256 key
)
    pure
    returns (bytes4 magicValue)
{
    uint256 message = uint256(keccak256(data));

    // A very silly signing scheme where the `message = signature ^ key`
    if (message == signature ^ key) {
        magicValue = ISignatureValidator.isValidSignature.selector;
    }
}

contract UniqueSignerFactory is IUniqueSignerFactory {
    function getSigner(bytes calldata data) public view returns (address signer) {
        uint256 key = abi.decode(data, (uint256));
        signer = _getSigner(key);
    }

    function createSigner(bytes calldata data) external returns (address signer) {
        uint256 key = abi.decode(data, (uint256));
        signer = _getSigner(key);
        if (_hasNoCode(signer)) {
            TestUniqueSigner created = new TestUniqueSigner{ salt: bytes32(0) }(key);
            require(address(created) == signer);
        }
    }

    function isValidSignatureForSigner(
        bytes memory data,
        bytes memory signatureData,
        bytes memory signerData
    )
        external
        pure
        override
        returns (bytes4 magicValue)
    {
        uint256 key = abi.decode(signerData, (uint256));
        uint256 signature = abi.decode(signatureData, (uint256));
        magicValue = checkSignature(data, signature, key);
    }

    function _getSigner(uint256 key) internal view returns (address) {
        bytes32 codeHash = keccak256(abi.encodePacked(type(TestUniqueSigner).creationCode, key));
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(hex"ff", address(this), bytes32(0), codeHash)))
            )
        );
    }

    function _hasNoCode(address account) internal view returns (bool) {
        uint256 size;
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            size := extcodesize(account)
        }
        /* solhint-enable no-inline-assembly */
        return size == 0;
    }
}

contract TestUniqueSigner is ISignatureValidator {
    uint256 public immutable KEY;

    constructor(uint256 key) {
        KEY = key;
    }

    function isValidSignature(
        bytes memory data,
        bytes memory signatureData
    )
        public
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        uint256 signature = abi.decode(signatureData, (uint256));
        magicValue = checkSignature(data, signature, KEY);
    }
}
