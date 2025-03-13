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
        IAccountFactory.ModuleInitData[] memory validators,
        IAccountFactory.ModuleInitData[] memory executors,
        IAccountFactory.ModuleInitData memory hook,
        IAccountFactory.ModuleInitData[] memory fallbacks
    )
        public
        pure
        override
        returns (bytes memory _init)
    {
        address[] memory attesters = new address[](1);
        attesters[0] = address(0x000000333034E9f539ce08819E12c1b8Cb29084d);

        ValidationId rootValidator =
            ValidatorLib.validatorToIdentifier(IValidator(validators[0].module));
        // Encode the rest of the validators, executors and fallbacks are onInstall calls with the
        // appropriate address and initData
        bytes[] memory otherModules =
            new bytes[](validators.length - 1 + executors.length + fallbacks.length);
        uint256 index = 0;
        for (uint256 i = 1; i < validators.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_VALIDATOR, validators[i].module, validators[i].data)
            );
            index++;
        }
        for (uint256 i = 0; i < executors.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_EXECUTOR, executors[i].module, executors[i].data)
            );
            index++;
        }
        for (uint256 i = 0; i < fallbacks.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_FALLBACK, fallbacks[i].module, fallbacks[i].data)
            );
            index++;
        }
        _init = abi.encodeCall(
            IKernel.initialize,
            (
                rootValidator,
                IHook(address(hook.module)),
                validators[0].data,
                hook.data,
                otherModules
            )
        );
    }

    function getInitData(bytes memory initData) public pure returns (bytes memory _init) {
        (
            ModuleBootstrapConfig[] memory validators,
            ModuleBootstrapConfig[] memory executors,
            ModuleBootstrapConfig memory hook,
            ModuleBootstrapConfig[] memory fallbacks
        ) = abi.decode(
            initData,
            (
                ModuleBootstrapConfig[],
                ModuleBootstrapConfig[],
                ModuleBootstrapConfig,
                ModuleBootstrapConfig[]
            )
        );
        ValidationId rootValidator =
            ValidatorLib.validatorToIdentifier(IValidator(validators[0].module));
        // Encode the rest of the validators, executors and fallbacks are onInstall calls with the
        // appropriate address and initData
        bytes[] memory otherModules =
            new bytes[](validators.length - 1 + executors.length + fallbacks.length);
        uint256 index = 0;
        for (uint256 i = 1; i < validators.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_VALIDATOR, validators[i].module, validators[i].initData)
            );
            index++;
        }
        for (uint256 i = 0; i < executors.length; i++) {
            otherModules[index] = abi.encodeCall(
                IKernel.installModule,
                (MODULE_TYPE_EXECUTOR, executors[i].module, executors[i].initData)
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
                validators[0].initData,
                hook.initData,
                otherModules
            )
        );
    }

    function setHookMultiPlexer(address hook) public {
        hookMultiPlexer = MockHookMultiPlexer(hook);
    }
}
