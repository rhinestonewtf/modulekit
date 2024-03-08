import "./SafeLaunchpad.sol";

contract SignerFactory is IUniqueSignerFactory {
    function getSigner(bytes memory data) external view override returns (address signer) { }

    function createSigner(bytes memory data) external override returns (address signer) { }

    function isValidSignatureForSigner(
        bytes32 message,
        bytes calldata signature,
        bytes calldata signerData
    )
        external
        view
        override
        returns (bytes4 magicValue)
    { }
}
