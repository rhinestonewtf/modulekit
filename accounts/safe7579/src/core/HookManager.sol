// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ModuleManager.sol";
import "erc7579/interfaces/IERC7579Account.sol";
import "erc7579/interfaces/IERC7579Module.sol";

/**
 * @title reference implementation of HookManager
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract HookManager is ModuleManager {
    /// @custom:storage-location erc7201:hookmanager.storage.msa
    struct HookManagerStorage {
        IHook _hook;
    }

    mapping(address smartAccount => HookManagerStorage) private _hookManagerStorage;

    // keccak256("hookmanager.storage.msa");
    bytes32 constant HOOKMANAGER_STORAGE_LOCATION =
        0x36e05829dd1b9a4411d96a3549582172d7f071c1c0db5c573fcf94eb28431608;

    error HookPostCheckFailed();
    error HookAlreadyInstalled(address currentHook);

    modifier withHook() {
        address hook = _getHook(msg.sender);
        if (hook == address(0)) {
            _;
        } else {
            bytes memory retData = _executeReturnData({
                safe: msg.sender,
                target: hook,
                value: 0,
                callData: abi.encodeCall(IHook.preCheck, (_msgSender(), msg.data))
            });
            bytes memory hookPreContext = abi.decode(retData, (bytes));

            _;
            retData = _executeReturnData({
                safe: msg.sender,
                target: hook,
                value: 0,
                callData: abi.encodeCall(IHook.postCheck, (hookPreContext))
            });
            bool success = abi.decode(retData, (bool));

            if (!success) revert HookPostCheckFailed();
        }
    }

    function _setHook(address hook) internal virtual {
        _hookManagerStorage[msg.sender]._hook = IHook(hook);
    }

    function _installHook(address hook, bytes calldata data) internal virtual {
        address currentHook = _getHook(msg.sender);
        if (currentHook != address(0)) {
            revert HookAlreadyInstalled(currentHook);
        }
        _setHook(hook);
        IHook(hook).onInstall(data);
    }

    function _uninstallHook(address hook, bytes calldata data) internal virtual {
        _setHook(address(0));
        IHook(hook).onUninstall(data);
    }

    function _getHook(address smartAccount) internal view returns (address _hook) {
        return address(_hookManagerStorage[smartAccount]._hook);
    }

    function _isHookInstalled(address module) internal view returns (bool) {
        return _getHook(msg.sender) == module;
    }

    function getActiveHook() external view returns (address hook) {
        return _getHook(msg.sender);
    }
}
