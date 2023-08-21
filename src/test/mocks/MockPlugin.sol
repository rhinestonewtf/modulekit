// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/modules/plugin/IPluginBase.sol";
import "forge-std/interfaces/IERC20.sol";

/// @author zeroknots

contract MockPlugin is IPluginBase {
    using ModuleExecLib for IPluginManager;

    function exec(IPluginManager manager, address account, address token, address receiver, uint256 amount) external {
        manager.exec({
            account: account,
            target: token,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount)
        });
    }

    function name() external view override returns (string memory name) {}

    function version() external view override returns (string memory version) {}

    function metadataProvider() external view override returns (uint256 providerType, bytes memory location) {}

    function requiresRootAccess() external view override returns (bool requiresRootAccess) {}
}
