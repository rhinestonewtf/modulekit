// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.23;

import { ERC7579FallbackBase } from "../Modules.sol";
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
        (bytes4[] memory selector, FallBackType[] memory fallbackType, address[] memory handler) =
            abi.decode(data, (bytes4[], FallBackType[], address[]));

        uint256 length = selector.length;
        if (length != fallbackType.length || length != handler.length) revert();
        for (uint256 i; i < length; i++) {
            _setFunctionSig(msg.sender, selector[i], fallbackType[i], handler[i]);
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

    mapping(address account => mapping(bytes4 => FallbackConfig)) public fallbackHandlers;

    // --- internal ---

    function _setFunctionSig(
        address account,
        bytes4 selector,
        FallBackType fallbackType,
        address handler
    )
        internal
    {
        fallbackHandlers[account][selector] =
            FallbackConfig({ fallbackType: fallbackType, handler: handler });
        emit SetFunctionSig(account, selector, fallbackType, handler);
    }

    function setFunctionSig(bytes4 selector, FallBackType fallbackType, address handler) external {
        _setFunctionSig(msg.sender, selector, fallbackType, handler);
    }

    fallback(bytes calldata) external returns (bytes memory result) {
        require(msg.data.length >= 24, "invalid method selector");
        FallbackConfig memory fallbackConfig = fallbackHandlers[msg.sender][msg.sig];
        address erc2771Sender = _msgSender();
        if (fallbackConfig.handler == address(0)) revert();

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

    function version() external pure virtual override returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual override returns (string memory) {
        return "ExtensibleFallbackHandler";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_FALLBACK;
    }
}
