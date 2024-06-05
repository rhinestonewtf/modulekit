// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { HelperBase } from "./HelperBase.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { IERC7579Account, MODULE_TYPE_HOOK } from "../../external/ERC7579.sol";
import { HookType } from "safe7579/DataTypes.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";

contract SafeHelpers is HelperBase {
    /**
     * get callData to install hook on ERC7579 Account
     */
    function installHook(
        address, /* account */
        address hook,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule,
            (MODULE_TYPE_HOOK, hook, abi.encode(HookType.GLOBAL, bytes4(0x0), initData))
        );
    }

    function execUserOp(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        public
        virtual
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        if (initCode.length != 0) {
            (initCode, callData) = getInitCallData(instance.salt, txValidator, initCode, callData);
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, callData, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    function configModuleUserOp(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        bool isInstall,
        address txValidator
    )
        public
        virtual
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        if (instance.account.code.length == 0) {
            initCode = instance.initCode;
        }

        bytes memory callData;
        if (isInstall) {
            callData = installModule({
                account: instance.account,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
        } else {
            callData = uninstallModule({
                account: instance.account,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
        }
        if (initCode.length != 0) {
            (initCode, callData) = getInitCallData(instance.salt, txValidator, initCode, callData);
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, callData, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    function getInitCallData(
        bytes32 salt,
        address txValidator,
        bytes memory originalInitCode,
        bytes memory erc4337CallData
    )
        public
        returns (bytes memory initCode, bytes memory callData)
    {
        // TODO: refactor this to decode the initcode
        address factory;
        assembly {
            factory := mload(add(originalInitCode, 20))
        }
        Safe7579Launchpad.InitData memory initData = abi.decode(
            IAccountFactory(factory).getInitData(txValidator, ""),
            (Safe7579Launchpad.InitData)
        );
        // Safe7579Launchpad.InitData memory initData =
        //     abi.decode(_initCode, (Safe7579Launchpad.InitData));
        initData.callData = erc4337CallData;
        initCode = abi.encodePacked(
            factory, abi.encodeCall(SafeFactory.createAccount, (salt, abi.encode(initData)))
        );
        callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        bytes memory data;

        if (moduleTypeId == MODULE_TYPE_HOOK) {
            data = abi.encode(HookType.GLOBAL, bytes4(0x0), "");
        }

        return isModuleInstalled(instance, moduleTypeId, module, data);
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            data = abi.encode(HookType.GLOBAL, bytes4(0x0), data);
        }

        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }
}
