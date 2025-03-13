// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { IKernelFactory as IKernelAccountFactory } from
    "../../accounts/kernel/interfaces/IKernelFactory.sol";
import { IKernel } from "../../accounts/kernel/interfaces/IKernel.sol";
import { ENTRYPOINT_ADDR } from "../../deployment/predeploy/EntryPoint.sol";
import { ValidatorLib } from "../../accounts/kernel/lib/ValidationTypeLib.sol";
import { ValidationId } from "../../accounts/kernel/types/Types.sol";
import { IValidator } from "../../accounts/common/interfaces/IERC7579Module.sol";
import { IHook } from "../../accounts/kernel/interfaces/IERC7579Module.sol";
import { IAccountFactory } from "../../accounts/factory/interface/IAccountFactory.sol";
import { MockHookMultiPlexer } from "../../Mocks.sol";
import { KernelPrecompiles } from "../../deployment/precompiles/KernelPrecompiles.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "./types/Constants.sol";

struct ModuleBootstrapConfig {
    address module;
    bytes initData;
}

contract KernelFactory is IAccountFactory, KernelPrecompiles {
    IKernelAccountFactory internal factory;
    IKernel internal kernelImpl;
    MockHookMultiPlexer public hookMultiPlexer;

    function init() public override {
        kernelImpl = deployKernel(ENTRYPOINT_ADDR);
        factory = deployKernelFactory(address(kernelImpl));
        hookMultiPlexer = new MockHookMultiPlexer();
    }

    function createAccount(
        bytes32 salt,
        bytes memory data
    )
        public
        override
        returns (address account)
    {
        account = factory.createAccount(data, salt);
    }

    function getAddress(bytes32 salt, bytes memory data) public override returns (address) {
        return factory.getAddress(data, salt);
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        public
        view
        override
        returns (bytes memory _init)
    {
        ValidationId rootValidator = ValidatorLib.validatorToIdentifier(IValidator(validator));

        _init = abi.encodeCall(
            IKernel.initialize,
            (rootValidator, IHook(address(hookMultiPlexer)), initData, hex"00", new bytes[](0))
        );
    }

    function getInitData(
        ModuleBootstrapConfig[] memory _validators,
        ModuleBootstrapConfig[] memory _executors,
        ModuleBootstrapConfig memory hook,
        ModuleBootstrapConfig[] memory fallbacks
    )
        public
        pure
        returns (bytes memory _init)
    {
        ValidationId rootValidator =
            ValidatorLib.validatorToIdentifier(IValidator(_validators[0].module));
        // Encode the rest of the validators, executors and fallbacks are onInstall calls with the
        // appropriate address and initData
        bytes[] memory otherModules =
            new bytes[](_validators.length - 1 + _executors.length + fallbacks.length);
        uint256 index = 0;
        for (uint256 i = 1; i < _validators.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_VALIDATOR, _validators[i].module, _validators[i].initData)
            );
            index++;
        }
        for (uint256 i = 0; i < _executors.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_EXECUTOR, _executors[i].module, _executors[i].initData)
            );
            index++;
        }
        for (uint256 i = 0; i < fallbacks.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_FALLBACK, fallbacks[i].module, fallbacks[i].initData)
            );
            index++;
        }
        _init = abi.encodeCall(
            IKernel.initialize,
            (
                rootValidator,
                IHook(address(hook.module)),
                _validators[0].initData,
                hook.initData,
                otherModules
            )
        );
    }

    function setHookMultiPlexer(address hook) public {
        hookMultiPlexer = MockHookMultiPlexer(hook);
    }
}
