// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC7579HookBase } from "modulekit/src/Modules.sol";
import {
    ModeLib,
    CallType,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL,
    ModeSelector
} from "erc7579/lib/ModeLib.sol";

import "forge-std/console2.sol";

contract MockHook is ERC7579HookBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    // Handled by the base
    // TODO: best devx for setting forwarder
    mapping(address account => address) public trustedForwarder;

    function setForwarder(address forwarder) external {
        trustedForwarder[msg.sender] = forwarder;
    }

    function isTrustedForwarder(address forwarder, address account) public view returns (bool) {
        return true;
        return forwarder == trustedForwarder[account];
    }

    function _msgSender() internal view returns (address account) {
        account = msg.sender;
        address _account;
        address forwarder;
        if (msg.data.length >= 40) {
            assembly {
                _account := shr(96, calldataload(sub(calldatasize(), 20)))
                forwarder := shr(96, calldataload(sub(calldatasize(), 40)))
            }
            if (forwarder == msg.sender && isTrustedForwarder(forwarder, _account)) {
                account = _account;
            }
        }
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        returns (bytes memory hookData)
    {
        return _preCheck(_msgSender(), msgSender, msgValue, msgData);
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
    {
        _postCheck(_msgSender(), hookData, executionSuccess, executionReturnValue);
    }

    // End of handled by the base

    function _preCheck(
        address account,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (bytes memory hookData)
    {
        ModeSelector mode = ModeSelector.wrap(bytes4(msgData[10:14]));

        if (mode == ModeSelector.wrap(bytes4(keccak256(abi.encode("revert"))))) {
            revert("revert");
        } else if (mode == ModeSelector.wrap(bytes4(keccak256(abi.encode("revertPost"))))) {
            hookData = abi.encode("revertPost");
        } else {
            hookData = abi.encode("success");
        }
    }

    function _postCheck(
        address account,
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        internal
    {
        if (keccak256(hookData) == keccak256(abi.encode("revertPost"))) {
            revert("revertPost");
        }
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_HOOK;
    }
}
