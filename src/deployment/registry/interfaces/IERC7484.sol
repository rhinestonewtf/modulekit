// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

// Types
import { ModuleType } from "../types/DataTypes.sol";

interface IERC7484 {
    event NewTrustedAttesters(address indexed smartAccount);
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*          Check with Registry internal attesters            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function check(address module) external view;

    function checkForAccount(address smartAccount, address module) external view;

    function check(address module, ModuleType moduleType) external view;

    function checkForAccount(
        address smartAccount,
        address module,
        ModuleType moduleType
    )
        external
        view;

    /**
     * Allows Smart Accounts - the end users of the registry - to appoint
     * one or many attesters as trusted.
     * @dev this function reverts, if address(0), or duplicates are provided in attesters[]
     *
     * @param threshold The minimum number of attestations required for a module
     *                  to be considered secure.
     * @param attesters The addresses of the attesters to be trusted.
     */
    function trustAttesters(uint8 threshold, address[] calldata attesters) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              Check with external attester(s)               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function check(address module, address[] calldata attesters, uint256 threshold) external view;

    function check(
        address module,
        ModuleType moduleType,
        address[] calldata attesters,
        uint256 threshold
    )
        external
        view;
}
