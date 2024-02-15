// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint } from "../../external/ERC4337.sol";

struct TmpStorage {
    mapping(address account => IEntryPoint entrypoint) entrypoint;
}

bytes32 constant STORAGE_SLOT = keccak256("forge.rhinestone.ModuleKitHelpers");

library ModuleKitCache {
    function getStorage() internal pure returns (TmpStorage storage _str) {
        bytes32 _slot = STORAGE_SLOT;

        assembly {
            _str.slot := _slot
        }
    }

    function logEntrypoint(address account, IEntryPoint entrypoint) internal {
        TmpStorage storage str = getStorage();
        str.entrypoint[account] = entrypoint;
    }

    function getEntrypoint(address account) internal view returns (IEntryPoint entrypoint) {
        TmpStorage storage str = getStorage();
        return str.entrypoint[account];
    }
}
