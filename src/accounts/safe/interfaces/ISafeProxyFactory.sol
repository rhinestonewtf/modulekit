// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

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
