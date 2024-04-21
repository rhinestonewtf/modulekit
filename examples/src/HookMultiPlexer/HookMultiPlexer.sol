// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase, ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import { ERC7579HookBaseNew } from "modulekit/src/modules/ERC7579HookBaseNew.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import { IERC7579Account, Execution } from "modulekit/src/Accounts.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract HookMultiPlexer is ERC7579HookBase, ERC7579ExecutorBase {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error NoHookRegistered(address smartAccount);
    error HookReverted(address hookAddress, bytes hookData);
    error InvalidHookInitDataLength();

    mapping(address account => SentinelListLib.SentinelList) hooks;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) {
            revert AlreadyInitialized(account);
        }

        (address[] memory hookAddresses, bytes[] memory initDatas) =
            abi.decode(data, (address[], bytes[]));

        if (hookAddresses.length != initDatas.length) {
            revert InvalidHookInitDataLength();
        }

        hooks[account].init();

        uint256 hooksLength = hookAddresses.length * 2;

        Execution[] memory executions = new Execution[](hooksLength);

        for (uint256 i = 0; i < hooksLength; i += 2) {
            address _hook = hookAddresses[i];
            // TODO: add registry check?
            hooks[account].push(_hook);
            executions[i] = Execution({
                target: _hook,
                value: 0,
                callData: abi.encodeWithSelector(this.onInstall.selector, initDatas[i])
            });

            executions[i + 1] = Execution({
                target: _hook,
                value: 0,
                callData: abi.encodeWithSelector(
                    ERC7579HookBaseNew.setTrustedForwarder.selector, address(this)
                )
            });
        }

        IERC7579Account(account).executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)
        );
    }

    function onUninstall(bytes calldata) external override {
        // TODO: Implement onUninstall
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return hooks[smartAccount].alreadyInitialized();
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
        (address[] memory selectedHooks,) = hooks[msg.sender].getEntriesPaginated(SENTINEL, 10);
        uint256 hooksLength = selectedHooks.length;

        bytes[] memory hookReturnDataArray = new bytes[](hooksLength);

        for (uint256 i = 0; i < hooksLength; i++) {
            address hookAddress = selectedHooks[i];

            if (hookAddress == address(0)) {
                revert NoHookRegistered(msg.sender);
            }

            (bool success, bytes memory _hookReturnData) = hookAddress.call(
                abi.encodePacked(
                    abi.encodeWithSelector(this.preCheck.selector, msgSender, msgValue, msgData),
                    address(this),
                    msg.sender
                )
            );

            if (!success) {
                revert HookReverted(hookAddress, _hookReturnData);
            }

            hookReturnDataArray[i] = _hookReturnData;
        }

        hookReturnData = abi.encode(hookReturnDataArray);
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
    {
        (address[] memory selectedHooks,) = hooks[msg.sender].getEntriesPaginated(SENTINEL, 10);
        uint256 hooksLength = selectedHooks.length;

        for (uint256 i = 0; i < hooksLength; i++) {
            address hookAddress = selectedHooks[i];
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
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "HookMultiPlexer";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK || typeID == TYPE_EXECUTOR;
    }
}
