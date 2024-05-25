// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SafeFactory } from "./safe/SafeFactory.sol";
import { ERC7579Factory } from "./erc7579/ERC7579Factory.sol";
import { AccountType, getAccountType } from "./MultiAccountHelpers.sol";

contract MultiAccountFactory is SafeFactory, ERC7579Factory {
    AccountType public env;

    constructor() {
        env = getAccountType();
    }

    function createAccount(
        bytes32 salt,
        bytes calldata initCode
    )
        public
        returns (address account)
    {
        if (env == AccountType.SAFE) {
            return createSafe(salt, initCode);
        } else {
            return createERC7579(salt, initCode);
        }
    }

    function getAddress(bytes32 salt, bytes memory initCode) public view returns (address) {
        if (env == AccountType.SAFE) {
            return getAddressSafe(salt, initCode);
        } else {
            return getAddressERC7579(salt, initCode);
        }
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        external
        view
        returns (bytes memory init)
    {
        if (env == AccountType.SAFE) {
            init = getInitDataSafe(validator, initData);
        } else {
            init = getInitDataERC7579(validator, initData);
        }
    }
}
