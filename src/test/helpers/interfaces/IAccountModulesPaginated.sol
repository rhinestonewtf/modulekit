// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAccountModulesPaginated {
    function getValidatorsPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);

    function getExecutorsPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);
}
