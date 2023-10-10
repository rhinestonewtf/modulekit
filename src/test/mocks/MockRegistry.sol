// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../common/IERC7484.sol";

/// @title MockRegistry
/// @author zeroknots
contract MockRegistry is IERC7484Registry {
    function check(
        address executor,
        address trustedAuthority
    )
        external
        view
        override
        returns (uint256 listedAt)
    {
        return 1337;
    }
}
