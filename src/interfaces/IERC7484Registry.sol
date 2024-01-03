// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IERC7484Registry {
    function check(
        address executor,
        address trustedAuthority
    )
        external
        view
        returns (uint256 listedAt);

    function checkN(
        address module,
        address[] memory attesters,
        uint256 threshold
    )
        external
        view
        returns (uint256[] memory);
}
