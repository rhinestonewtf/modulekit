// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC7579HookBase } from "modulekit/src/Modules.sol";

contract HookMultiPlexer is ERC7579HookBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error NoHookRegistered(address smartAccount);
    error HookReverted(address hookAddress, bytes hookData);

    event HookAdded(address indexed smartAccount, address hookAddress);

    mapping(address account => address) hook;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address hookAddress = abi.decode(data, (address));
        hook[msg.sender] = hookAddress;

        emit HookAdded(msg.sender, hookAddress);
    }

    function onUninstall(bytes calldata) external override {
        delete hook[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return hook[smartAccount] != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        returns (bytes memory hookReturnData)
    {
        address hookAddress = hook[msg.sender];
        if (hookAddress == address(0)) {
            revert NoHookRegistered(msg.sender);
        }

        bool success;

        (success, hookReturnData) = hookAddress.call(
            abi.encodePacked(
                abi.encodeWithSelector(this.preCheck.selector, msgSender, msgValue, msgData),
                address(this),
                msg.sender
            )
        );

        if (!success) {
            revert HookReverted(hookAddress, hookReturnData);
        }
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
    {
        address hookAddress = hook[msg.sender];
        if (hookAddress == address(0)) {
            revert NoHookRegistered(msg.sender);
        }

        (bool success, bytes memory hookReturnData) = hookAddress.call(
            abi.encodePacked(
                abi.encodeWithSelector(
                    this.postCheck.selector, hookData, executionSuccess, executionReturnValue
                ),
                address(this),
                msg.sender
            )
        );

        if (!success) {
            revert HookReverted(hookAddress, hookReturnData);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "HookMultiPlexer";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK;
    }
}
