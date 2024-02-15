// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-unused-vars */
import { IERC7484Registry } from "../interfaces/IERC7484Registry.sol";
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

    function checkN(
        address module,
        address[] memory attesters,
        uint256 threshold
    )
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256 attestersLength = attesters.length;
        uint256[] memory attestedAtArray = new uint256[](attestersLength);
        for (uint256 i; i < attestersLength; ++i) {
            attestedAtArray[i] = uint256(1234);
        }
        return attestedAtArray;
    }
}
