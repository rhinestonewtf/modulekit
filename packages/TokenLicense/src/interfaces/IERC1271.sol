interface IERC1271 {
    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature
    )
        external
        view
        returns (bytes4 magicValue);
}
