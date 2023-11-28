// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC4337Wrappers } from "./ERC4337Helpers.sol";
import "murky/Merkle.sol";
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
import { SessionKeyManager } from "../../../core/SessionKeyManager.sol";
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
import "../Log.sol";

struct RhinestoneAccount {
    address account;
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
        sessionKeyManager = new SessionKeyManager(16,132);
        label(address(sessionKeyManager), "sessionKeyManager");

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
        // overwriting the env.executorManager with the kernel style executor manager
        env.executorManager = ExecutorManager(address(kernelStyleExecManager));
        // bytes memory initCallData = abi.encodeCall(
        //     IKernel.setDefaultValidator, (IKernelValidator(address(kernelStyleExecManager)), "")
        // );

        instance = RhinestoneAccount({
            account: kernelFactory.createAccount(address(accountSingleton), "", uint256(salt)),
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({
                accountSingleton: accountSingleton,
                accountFactory: kernelFactory
            })
        });
        // instance.aux.executorManager = ExecutorManager(address(instance.aux.executorManager));
        RhinestoneModuleKitLib.setDefaultValidator(instance);
        label(instance.account, "account instance");
    }

    function getAccountAddress(bytes memory data, bytes32 salt) internal view returns (address) {
        return IKernelFactory(kernelFactory).getAccountAddress(data, uint256(salt));
    }
}

library RhinestoneModuleKitLib {
    /*//////////////////////////////////////////////////////////////////////////
                                EXEC4337
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param callData Calldata
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, 0, callData);
    }

    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value
     * @param callData Calldata
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, value, callData, hex"41414141", address(instance.aux.validator));
    }

    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value
     * @param callData Calldata
     * @param signature Signature
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature
    )
        internal
    {
        bytes memory data = ERC4337Wrappers.getKernel4337TxCalldata(target, value, callData);
        signature = encodeSig(encodeValidator(instance, signature, address(instance.aux.validator)));
        exec4337(instance, data, signature);
    }

    /**
     * @dev Executes an ERC-4337 transaction
     * @dev this is an internal function that assumes that calldata is already correctly formatted
     * @dev only use this function if you want to manually encode the calldata, otherwise use the functions above
     *
     * @param instance RhinestoneAccount
     * @param callData ENcoded callData
     * @param signature Signature
     */
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

        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULES
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Adds a validator to the account
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     */
    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        setDefaultValidator(instance);
        // add validator to instance.aux.executorManager
        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            callData: abi.encodeCall(KernelExecutorManager.addValidator, (validator))
        });
    }

    function removeValidator(RhinestoneAccount memory instance, address validator) internal {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) = KernelExecutorManager(
            address(instance.aux.executorManager)
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
            target: address(instance.aux.executorManager),
            callData: abi.encodeCall(KernelExecutorManager.removeValidator, (previous, validator))
        });
    }

    /**
     * @dev Checks if a validator is enabled
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     *
     * @return isEnabled True if validator is enabled
     */
    function isValidatorEnabled(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bool isEnabled)
    {
        address defaultValidator = IKernel(instance.account).getDefaultValidator();
        if (defaultValidator != address(instance.aux.executorManager)) {
            return false;
        }
        isEnabled =
            KernelExecutorManager(defaultValidator).isValidatorEnabled(instance.account, validator);
    }

    /**
     * @dev Adds a session key to the account
     *
     * @param instance RhinestoneAccount
     * @param validUntil Valid until timestamp
     * @param validAfter Valid after timestamp
     * @param sessionValidationModule Session validation module address
     * @param sessionKeyData Session key data
     *
     * @return root Merkle root of session key manager
     * @return proof Merkle proof for session key
     */
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
            !KernelExecutorManager(address(instance.aux.executorManager)).isValidatorEnabled(
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
        leaves[0] = leaf;
        leaves[1] = leaf;

        root = m.getRoot(leaves);
        proof = m.getProof(leaves, 1);

        exec4337(
            instance,
            address(instance.aux.sessionKeyManager),
            abi.encodeCall(instance.aux.sessionKeyManager.setMerkleRoot, (root))
        );
    }

    /**
     * @dev Adds a hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     */
    function addHook(RhinestoneAccount memory instance, address hook) internal {
        revert("Not supported yet");
    }

    /**
     * @dev Checks if a hook is enabled
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     *
     * @return isEnabled True if hook is enabled
     */

    function isHookEnabled(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bool isEnabled)
    {
        revert("Not supported yet");
    }

    /**
     * @dev Adds an executor to the account
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     */
    function addExecutor(RhinestoneAccount memory instance, address executor) internal {
        setDefaultValidator(instance);
        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            callData: abi.encodeCall(ExecutorManager.enableExecutor, (executor, false))
        });
    }

    /**
     * @dev Removes an executor from the account
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     */
    function removeExecutor(RhinestoneAccount memory instance, address executor) internal {
        address previous;
        (address[] memory array, address next) = ExecutorManager(
            address(instance.aux.executorManager)
        ).getExecutorsPaginated(address(0x1), 100, instance.account);

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
            target: address(instance.aux.executorManager),
            callData: abi.encodeCall(ExecutorManager.disableExecutor, (previous, executor))
        });
    }

    /**
     * @dev Gets the formatted UserOperation
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value to send
     * @param callData Calldata
     *
     * @return userOp Formatted UserOperation
     */
    function getFormattedUserOp(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOperation memory userOp)
    {
        bytes memory data = ERC4337Wrappers.getKernel4337TxCalldata(target, value, callData);
        // bytes memory initCode = isDeployed(instance) ? bytes("") : "";
        bytes memory initCode = "";
        userOp = ERC4337Wrappers.getPartialUserOp(
            instance.account, instance.aux.entrypoint, data, initCode
        );
    }
    /**
     * @dev Checks if an executor is enabled
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     *
     * @return isEnabled True if executor is enabled
     */

    function isExecutorEnabled(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bool isEnabled)
    {
        isEnabled = instance.aux.executorManager.isExecutorEnabled(instance.account, executor);
    }

    /**
     * @dev Adds a condition to the Condition Manager
     *
     * @param instance RhinestoneAccount
     * @param forExecutor Executor address for which the condition is used
     * @param conditions Condition config
     */
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

    function setDefaultValidator(RhinestoneAccount memory instance) internal {
        // get default validator from kernel
        address currentDefaultValidator = IKernel(instance.account).getDefaultValidator();

        // if default validator is not set to instance.aux.executorManager, set it
        if (currentDefaultValidator != address(instance.aux.executorManager)) {
            prank(address(instance.aux.entrypoint));
            IKernel(instance.account).setDefaultValidator(
                IKernelValidator(address(instance.aux.executorManager)),
                abi.encode(address(instance.aux.validator))
            );
        }
    }

    /**
     * @dev Adds a fallback handler to the account
     *
     * @param instance RhinestoneAccount
     * @param handleFunctionSig Function signature
     * @param isStatic True if function is static
     * @param handler Handler address
     */
    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
    {
        revert("Not supported yet");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Gets the user operation hash
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param callData Calldata
     *
     * @return userOpHash User operation hash
     */
    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    {
        UserOperation memory userOp = getFormattedUserOp(instance, target, value, callData);
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
        return userOpHash;
    }

    /**
     * @dev Encodes the signature
     *
     * @param sig Signature to encode
     *
     * @return encodedSig Signature encoded with mode
     */
    function encodeSig(bytes memory sig) internal pure returns (bytes memory) {
        bytes4 mode = 0;
        return abi.encodePacked(mode, sig);
    }

    /**
     * @dev Encodes the validator
     *
     * @param instance RhinestoneAccount
     * @param signature Signature
     * @param chosenValidator Validator address
     *
     * @return packedSignature Signature encoded with validator
     */
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

    /**
     * @dev Expects an ERC-4337 transaction to revert
     * @dev if this is called before an exec4337 call, it will throw an error if the ERC-4337 flow does not revert
     *
     * @param instance RhinestoneAccount
     */
    function expect4337Revert(RhinestoneAccount memory instance) internal {
        writeExpectRevert(1);
    }

    function isDeployed(RhinestoneAccount memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
