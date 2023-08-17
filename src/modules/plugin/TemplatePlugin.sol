// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../auxiliary/interfaces/IPluginBase.sol";
import "../../auxiliary/interfaces/IModuleManager.sol";
import "./ModuleExecLib.sol";
import "forge-std/interfaces/IERC20.sol";

/// @title TemplatePlugin
/// @author zeroknots

contract TemplatePlugin is IPluginBase {
    using ModuleExecLib for IModuleManager;

    function exec(IModuleManager account, IERC20 token, address receiver, uint256 amount) external {
        account.exec(address(token), abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount));
    }

    function name() external view override returns (string memory name) {}

    function version() external view override returns (string memory version) {}

    function metadataProvider() external view override returns (uint256 providerType, bytes memory location) {}

    function requiresRootAccess() external view override returns (bool requiresRootAccess) {}
}
