// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "./external/IERC165.sol";

interface IFeeMachine is IERC165 {
    function split(
        address module,
        ClaimTransaction calldata claim
    )
        external
        returns (Split[] memory);

    function split(ClaimSubscription calldata claim) external returns (Split[] memory);
}
