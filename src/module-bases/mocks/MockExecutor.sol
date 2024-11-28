// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579ExecutorBase } from "../ERC7579ExecutorBase.sol";
// solhint-disable-next-line no-unused-import
import { IERC7579Account } from "../../accounts/common/interfaces/IERC7579Account.sol";

contract MockExecutor is ERC7579ExecutorBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function exec(
        address account,
        address to,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory)
    {
        return _execute(account, to, value, callData);
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function isInitialized(
        address // smartAccount
    )
        external
        pure
        returns (bool)
    {
        return false;
    }
}
