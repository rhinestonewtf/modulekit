// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase, ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import { ERC7579HookBaseNew } from "modulekit/src/modules/ERC7579HookBaseNew.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import { IERC7579Account, Execution } from "modulekit/src/Accounts.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";

contract HookMultiPlexer is ERC7579HookBase, ERC7579ExecutorBase {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error NoHookRegistered(address smartAccount);
    error HookReverted(address hookAddress, bytes hookData);
    error InvalidHookInitDataLength();

    struct Config {
        address[] globalHooks;
        mapping(bytes4 => address[]) sigHooks;
        mapping(bytes4 => address[]) targetSigHooks;
        address[] valueHooks;
    }

    mapping(address account => Config) config;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    IERC7484 public immutable REGISTRY;

    constructor(IERC7484 _registry) {
        REGISTRY = _registry;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        // TODO
    }

    function onUninstall(bytes calldata) external override {
        // TODO
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        // TODO: this is a temporary solution
        return config[smartAccount].globalHooks.length != 0;
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
        address[] memory hooks =
            _getHooks(msg.sender, bytes4(msgData[0:4]), _getTargetSig(msgData), msgValue > 0);
        uint256 hooksLength = hooks.length;

        bytes[] memory hookReturnDataArray = new bytes[](hooksLength);

        for (uint256 i = 0; i < hooksLength; i++) {
            address hookAddress = hooks[i];

            (bool success, bytes memory _hookReturnData) = hookAddress.call(
                abi.encodePacked(
                    abi.encodeCall(this.preCheck, (msgSender, msgValue, msgData)),
                    address(this),
                    msg.sender
                )
            );

            if (!success) {
                revert HookReverted(hookAddress, _hookReturnData);
            }

            hookReturnDataArray[i] = _hookReturnData;
        }

        hookReturnData = abi.encodePacked(
            bytes4(msgData[0:4]),
            _getTargetSig(msgData),
            msgValue > 0,
            abi.encode(hookReturnDataArray)
        );
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
    {
        (bytes4 sig, bytes4 targetSig, bool hasValue, bytes[] memory hookReturnDataArray) =
            abi.decode(hookData, (bytes4, bytes4, bool, bytes[]));

        address[] memory hooks = _getHooks(msg.sender, sig, targetSig, hasValue);
        uint256 hooksLength = hooks.length;

        for (uint256 i = 0; i < hooksLength; i++) {
            address hookAddress = hooks[i];

            (bool success,) = hookAddress.call(
                abi.encodePacked(
                    abi.encodeCall(
                        this.postCheck,
                        (hookReturnDataArray[i], executionSuccess, executionReturnValue)
                    ),
                    address(this),
                    msg.sender
                )
            );

            if (!success) {
                revert HookReverted(hookAddress, bytes(""));
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getTargetSig(bytes calldata msgData) internal pure returns (bytes4) {
        return bytes4(msgData[0:4]);
    }

    function _getHooks(
        address account,
        bytes4 sig,
        bytes4 targetSig,
        bool hasValue
    )
        internal
        returns (address[] memory)
    {
        address[] memory globals = config[account].globalHooks;
        address[] memory sigHooks = config[account].sigHooks[sig];
        address[] memory targetSigHooks = config[account].targetSigHooks[targetSig];

        address[] memory valueHooks;
        if (hasValue) {
            valueHooks = config[account].valueHooks;
        }

        uint256 hooksLength =
            globals.length + sigHooks.length + targetSigHooks.length + valueHooks.length;

        address[] memory hooks = new address[](hooksLength);

        // this needs to be optimized
        uint256 index = 0;
        for (uint256 i = 0; i < globals.length; i++) {
            hooks[index++] = globals[i];
        }

        for (uint256 i = 0; i < sigHooks.length; i++) {
            hooks[index++] = sigHooks[i];
        }

        for (uint256 i = 0; i < targetSigHooks.length; i++) {
            hooks[index++] = targetSigHooks[i];
        }

        for (uint256 i = 0; i < valueHooks.length; i++) {
            hooks[index++] = valueHooks[i];
        }

        return hooks;
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
