// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@rhinestone/modulekit/src/modules/ERC7579ExecutorBase.sol";
import "../DataTypes.sol";
import "../lib/Currency.sol";
import "../interfaces/external/IERC20Minimal.sol";

contract ApprovalExecutor is ERC7579ExecutorBase {
    function _setERC20Approval(Currency currency, address account, uint256 amount) internal {
        _execute({
            account: account,
            to: Currency.unwrap(currency),
            value: 0,
            data: abi.encodeCall(IERC20Minimal.approve, (address(this), amount))
        });
    }

    function _getNative(address account, uint256 amount) internal {
        _execute({ account: account, to: address(this), value: amount, data: "" });
    }

    function onInstall(bytes calldata data) external { }

    function onUninstall(bytes calldata data) external { }

    function isModuleType(uint256 typeID) external view returns (bool) { }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
