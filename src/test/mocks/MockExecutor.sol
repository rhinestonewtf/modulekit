// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IExecutorBase, ModuleExecLib, IExecutorManager } from "../../modulekit/IExecutor.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

/// @author zeroknots

contract MockExecutor is IExecutorBase {
    using ModuleExecLib for IExecutorManager;

    function exec(
        IExecutorManager manager,
        address account,
        address token,
        address receiver,
        uint256 amount
    )
        external
    {
        manager.exec({
            account: account,
            target: token,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount)
        });
    }

    function name() external view override returns (string memory name) { }

    function version() external view override returns (string memory version) { }

    function metadataProvider()
        external
        view
        override
        returns (uint256 providerType, bytes memory location)
    { }

    function requiresRootAccess() external view override returns (bool requiresRootAccess) { }
}
