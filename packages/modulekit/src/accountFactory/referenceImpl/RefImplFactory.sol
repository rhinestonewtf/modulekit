// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../external/ERC7579.sol";
import { LibClone } from "solady/utils/LibClone.sol";

interface IMSA {
    function initializeAccount(bytes calldata initCode) external;
}

abstract contract RefImplFactory {
    ERC7579Account internal implementation;
    ERC7579Bootstrap internal bootstrapDefault;

    constructor() {
        implementation = new ERC7579Account();
        bootstrapDefault = new ERC7579Bootstrap();
    }

    function _createUMSA(bytes32 salt, bytes memory initCode) public returns (address account) {
        bytes32 _salt = _getSalt(salt, initCode);
        address account = LibClone.cloneDeterministic(0, address(implementation), initCode, _salt);

        IMSA(account).initializeAccount(initCode);
        return account;
    }

    function getAddressUMSA(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        virtual
        returns (address)
    {
        bytes32 _salt = _getSalt(salt, initCode);
        return LibClone.predictDeterministicAddress(
            address(implementation), initCode, _salt, address(this)
        );
    }

    function _getSalt(
        bytes32 _salt,
        bytes memory initCode
    )
        public
        pure
        virtual
        returns (bytes32 salt);
}
