// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

interface ISafeProxyFactory {
    function proxyCreationCode() external pure returns (bytes memory);

    function createProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    )
        external
        returns (address proxy);

    function createChainSpecificProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    )
        external
        returns (address proxy);

    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        address callback
    )
        external
        returns (address proxy);

    function getChainId() external view returns (uint256);
}
