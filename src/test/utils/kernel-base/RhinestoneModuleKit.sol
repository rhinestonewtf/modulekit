// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC4337Wrappers } from "./ERC4337Helpers.sol";
import "murky/src/Merkle.sol";
import "src/test/utils/kernel-base/IKernel.sol";

import "forge-std/console2.sol";

import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";
import { ConditionConfig } from "../../../core/ComposableCondition.sol";
import { IBootstrap } from "src/common/IBootstrap.sol";
import { KernelExecutorManager } from "src/test/utils/kernel-base/KernelExecutorManager.sol";
import { IExecutorManager } from "src/modulekit/interfaces/IExecutor.sol";

import { ValidatorSelectionLib } from "src/modulekit/lib/ValidatorSelectionLib.sol";

import { ExecutorManager } from "src/core/ExecutorManager.sol";

import {
    IKernel,
    IKernelFactory,
    deployAccountSingleton,
    deployAccountFactory
} from "../dependencies/Kernel.sol";

import "../Vm.sol";

struct RhinestoneAccount {
    address account;
    IExecutorManager executorManager;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavor accountFlavor;
}

struct AccountFlavor {
    IKernel accountSingleton;
    IKernelFactory accountFactory;
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    IKernelFactory kernelFactory;
    IKernel accountSingleton;
    bool initialzed;

    function init() internal override {
        super.init();

        accountSingleton = deployAccountSingleton(address(entrypoint));
        kernelFactory = deployAccountFactory(address(this), address(entrypoint));

        kernelFactory.setImplementation(address(accountSingleton), true);
        label(address(accountSingleton), "accountSingleton");

        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!initialzed) init();
        Auxiliary memory env = makeAuxiliary(address(0), IBootstrap(address(0)), sessionKeyManager);

        IExecutorManager kernelStyleExecManager =
            IExecutorManager(address(new KernelExecutorManager(env.registry)));
        // bytes memory initCallData = abi.encodeCall(
        //     IKernel.setDefaultValidator, (IKernelValidator(address(kernelStyleExecManager)), "")
        // );

        instance = RhinestoneAccount({
            account: kernelFactory.createAccount(address(accountSingleton), "", uint256(salt)),
            executorManager: kernelStyleExecManager,
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({
                accountSingleton: accountSingleton,
                accountFactory: kernelFactory
            })
        });
        label(instance.account, "account instance");
    }

    function getAccountAddress(bytes memory data, bytes32 salt) internal view returns (address) {
        return IKernelFactory(kernelFactory).getAccountAddress(data, uint256(salt));
    }
}

library RhinestoneModuleKitLib {
    function encodeSig(bytes memory sig) internal pure returns (bytes memory) {
        bytes4 mode = 0;
        return abi.encodePacked(mode, sig);
    }

    function encodeValidator(
        RhinestoneAccount memory instance,
        bytes memory signature,
        address chosenValidator
    )
        internal
        pure
        returns (bytes memory packedSignature)
    {
        packedSignature = ValidatorSelectionLib.encodeValidator(signature, chosenValidator);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    {
        console2.log("validator", address(instance.aux.validator));
        exec4337(instance, target, value, callData, hex"41414141", address(instance.aux.validator));
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature,
        address validator
    )
        internal
    {
        bytes memory data = ERC4337Wrappers.getKernel4337TxCalldata(target, value, callData);
        exec4337({
            instance: instance,
            callData: data,
            signature: encodeSig(encodeValidator(instance, signature, validator))
        });
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, 0, callData);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        bytes memory callData,
        bytes memory signature
    )
        internal
    {
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(
            instance.account, instance.aux.entrypoint, callData, ""
        );
        userOp.signature = signature;
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        setDefaultValidator(instance);

        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function setCondition(
        RhinestoneAccount memory instance,
        address forExecutor,
        ConditionConfig[] memory conditions
    )
        internal
    {
        exec4337({
            instance: instance,
            target: address(instance.aux.compConditionManager),
            value: 0,
            callData: abi.encodeCall(
                instance.aux.compConditionManager.setHash, (forExecutor, conditions)
                )
        });
    }

    function addSessionKey(
        RhinestoneAccount memory instance,
        uint256 validUntil,
        uint256 validAfter,
        address sessionValidationModule,
        bytes memory sessionKeyData
    )
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        if (
            !KernelExecutorManager(address(instance.executorManager)).isValidatorEnabled(
                instance.account, address(instance.aux.sessionKeyManager)
            )
        ) {
            addValidator(instance, address(instance.aux.sessionKeyManager));
        }

        Merkle m = new Merkle();

        bytes32 leaf = instance.aux.sessionKeyManager._sessionMerkelLeaf({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: sessionValidationModule,
            sessionKeyData: sessionKeyData
        });

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = "asdf";
        leaves[1] = leaf;

        root = m.getRoot(leaves);
        proof = m.getProof(leaves, 1);

        exec4337(
            instance,
            address(instance.aux.sessionKeyManager),
            abi.encodeCall(instance.aux.sessionKeyManager.setMerkleRoot, (root))
        );
    }

    function setDefaultValidator(RhinestoneAccount memory instance) internal {
        // get default validator from kernel
        address currentDefaultValidator = IKernel(instance.account).getDefaultValidator();

        // if default validator is not set to instance.executorManager, set it
        if (currentDefaultValidator != address(instance.executorManager)) {
            prank(address(instance.aux.entrypoint));
            IKernel(instance.account).setDefaultValidator(
                IKernelValidator(address(instance.executorManager)),
                abi.encode(address(instance.aux.validator))
            );
        }
    }

    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        setDefaultValidator(instance);
        // add validator to instance.executorManager
        exec4337({
            instance: instance,
            target: address(instance.executorManager),
            callData: abi.encodeCall(
                KernelExecutorManager.addValidator, (address(instance.executorManager))
                )
        });
    }

    function removeValidator(RhinestoneAccount memory instance, address validator) internal {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) = KernelExecutorManager(
            address(instance.executorManager)
        ).getValidatorPaginated(address(0x1), 100, instance.account);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == validator) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == validator) previous = array[i - 1];
            }
        }
        exec4337({
            instance: instance,
            target: address(instance.executorManager),
            callData: abi.encodeCall(KernelExecutorManager.removeValidator, (previous, validator))
        });
    }

    function addExecutor(RhinestoneAccount memory instance, address executor) internal {
        setDefaultValidator(instance);
        exec4337({
            instance: instance,
            target: address(instance.executorManager),
            callData: abi.encodeCall(ExecutorManager.enableExecutor, (executor, false))
        });
    }

    function removeExecutor(RhinestoneAccount memory instance, address executor) internal {
        address previous;
        (address[] memory array, address next) = ExecutorManager(address(instance.executorManager))
            .getExecutorsPaginated(address(0x1), 100, instance.account);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == executor) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == executor) previous = array[i - 1];
            }
        }
        exec4337({
            instance: instance,
            target: address(instance.executorManager),
            callData: abi.encodeCall(ExecutorManager.disableExecutor, (previous, executor))
        });
    }

    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
    { }

    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    { }

    function isDeployed(RhinestoneAccount memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
