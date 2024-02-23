// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.23;

/* solhint-disable payable-fallback */
/* solhint-disable no-complex-fallback */

import { ERC7579FallbackBase } from "../modules/ERC7579FallbackBase.sol";
import { ERC2771Handler } from "./ERC2771Handler.sol";

interface IFallbackMethod {
    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        returns (bytes memory result);
}

interface IStaticFallbackMethod {
    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        view
        returns (bytes memory result);
}

contract ExtensibleFallbackHandler is ERC7579FallbackBase, ERC2771Handler {
    enum FallBackType {
        Static,
        Dynamic
    }

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;
        Params[] memory params = abi.decode(data, (Params[]));

        uint256 length = params.length;
        for (uint256 i; i < length; i++) {
            _setFunctionSig(msg.sender, params[i]);
        }
    }

    function onUninstall(bytes calldata data) external override { }
    // --- events ---

    event SetFunctionSig(
        address indexed account, bytes4 selector, FallBackType fallbackType, address handler
    );
    event RemovedFunctionSelector(address indexed account, bytes4 selector);

    // --- storage ---

    struct FallbackConfig {
        FallBackType fallbackType;
        address handler;
    }

    struct Params {
        bytes4 selector;
        FallBackType fallbackType;
        address handler;
    }

    mapping(address account => mapping(bytes4 => FallbackConfig)) public fallbackHandlers;

    // --- internal ---

    function _setFunctionSig(address account, Params memory params) internal {
        fallbackHandlers[account][params.selector] =
            FallbackConfig({ fallbackType: params.fallbackType, handler: params.handler });
        emit SetFunctionSig(account, params.selector, params.fallbackType, params.handler);
    }

    function setFunctionSig(Params memory params) external {
        _setFunctionSig(msg.sender, params);
    }

    fallback(bytes calldata) external returns (bytes memory result) {
        require(msg.data.length >= 24, "invalid method selector");
        FallbackConfig memory fallbackConfig = fallbackHandlers[msg.sender][msg.sig];
        address erc2771Sender = _msgSender();
        if (fallbackConfig.handler == address(0)) revert("Invalid Method");

        if (fallbackConfig.fallbackType == FallBackType.Static) {
            result = IStaticFallbackMethod(fallbackConfig.handler).handle(
                msg.sender,
                erc2771Sender,
                0,
                msg.data[:msg.data.length - 20] // remove ERC2771 sender
            );
        } else {
            result = IFallbackMethod(fallbackConfig.handler).handle(
                msg.sender,
                erc2771Sender,
                0,
                msg.data[:msg.data.length - 20] // remove ERC2771 sender
            );
        }
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_FALLBACK;
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }
}
