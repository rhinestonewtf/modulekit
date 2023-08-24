// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Rhinestone4337} from "../account/core/Rhinestone4337.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

import "./ISafe.sol";

contract RhinestoneSafeFlavor is Rhinestone4337 {
    constructor(address entryPoint, address registry, address trustedAuthority)
        Rhinestone4337(entryPoint, registry, trustedAuthority)
    {}

    function _execTransationOnSmartAccount(address safe, address to, uint256 value, bytes memory data)
        internal
        override
        returns (bool success, bytes memory)
    {
        success = ISafe(safe).execTransactionFromModule(to, value, data, 0);
    }

    function _execTransationOnSmartAccount(address to, uint256 value, bytes memory data)
        internal
        returns (bool success, bytes memory)
    {
        address safe = _accountAddress();
        return _execTransationOnSmartAccount(safe, to, value, data);
    }

    function _execDelegateCallOnSmartAccount(address to, uint256 value, bytes memory data)
        internal
        returns (bool success, bytes memory)
    {
        address safe = _accountAddress();
        success = ISafe(safe).execTransactionFromModule(to, value, data, 1);
    }

    function _accountAddress() internal virtual returns (address) {
        return owner();
    }

    function _msgSender() internal pure override returns (address sender) {
        // The assembly code is more direct than the Solidity version using `abi.decode`.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    function _prefundEntrypoint(address safe, address entryPoint, uint256 requiredPrefund) internal virtual override {
        ISafe(safe).execTransactionFromModule(entryPoint, requiredPrefund, "", 0);
    }

    receive() external payable {}
}
