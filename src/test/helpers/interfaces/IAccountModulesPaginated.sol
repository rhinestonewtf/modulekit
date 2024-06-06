// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAccountModulesPaginated {
    function getValidatorPaginated(
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
