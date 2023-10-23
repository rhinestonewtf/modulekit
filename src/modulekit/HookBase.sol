// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IHook, ExecutorTransaction } from "./interfaces/IHook.sol";
import { IERC165 } from "forge-std/interfaces/IERC165.sol";

abstract contract HookBase is IHook, IERC165 {
    function preCheck(
        address account,
        ExecutorTransaction calldata transaction,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        virtual
        returns (bytes memory preCheckData);

    function preCheckRootAccess(
        address account,
        ExecutorTransaction calldata rootAccess,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        virtual
        returns (bytes memory preCheckData);

    function postCheck(
        address account,
        bool success,
        bytes calldata preCheckData
    )
        external
        virtual;

    function supportsInterface(bytes4 interfaceID) external view virtual override returns (bool) {
        return interfaceID == IHook.preCheck.selector
            || interfaceID == IHook.preCheckRootAccess.selector
            || interfaceID == IHook.postCheck.selector;
    }
}
