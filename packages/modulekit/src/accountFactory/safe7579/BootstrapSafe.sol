// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@rhinestone/safe7579/src/core/ModuleManager.sol";
import "@rhinestone/safe7579/src/core/HookManager.sol";

import "../../external/ERC7579.sol";

contract BootstrapSafe is ModuleManager, HookManager {
    function singleInitMSA(IERC7579Validator validator, bytes calldata data) external {
        // init validator
        _installValidator(address(validator), data);
    }

    /**
     * This function is intended to be called by the MSA with a delegatecall.
     * Make sure that the MSA already initilazed the linked lists in the ModuleManager prior to
     * calling this function
     */
    function initMSA(
        ERC7579BootstrapConfig[] calldata _validators,
        ERC7579BootstrapConfig[] calldata _executors,
        ERC7579BootstrapConfig calldata _hook,
        ERC7579BootstrapConfig[] calldata _fallbacks
    )
        external
    {
        // init validators
        for (uint256 i; i < _validators.length; i++) {
            _installValidator(_validators[i].module, _validators[i].data);
        }

        // init executors
        for (uint256 i; i < _executors.length; i++) {
            if (_executors[i].module == address(0)) continue;
            _installExecutor(_executors[i].module, _executors[i].data);
        }

        // init hook
        if (_hook.module != address(0)) {
            _installHook(_hook.module, _hook.data);
        }

        // init fallbacks
        for (uint256 i; i < _fallbacks.length; i++) {
            if (_fallbacks[i].module == address(0)) continue;
            _installFallbackHandler(_fallbacks[i].module, _fallbacks[i].data);
        }
    }

    function _getInitMSACalldata(
        ERC7579BootstrapConfig[] calldata _validators,
        ERC7579BootstrapConfig[] calldata _executors,
        ERC7579BootstrapConfig calldata _hook,
        ERC7579BootstrapConfig[] calldata _fallbacks
    )
        external
        view
        returns (bytes memory init)
    {
        init = abi.encode(
            address(this),
            abi.encodeCall(this.initMSA, (_validators, _executors, _hook, _fallbacks))
        );
    }
}
