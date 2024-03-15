// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.23;

import { SuperTokenFactoryBase } from
    "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperTokenFactory.sol";

contract ModuleTokenFactory is SuperTokenFactoryBase {
    mapping(address module => address superToken) public moduleToSuperToken;

    function _createNewSuperToken(address module) { }
}
