// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IKernelFactory as IKernelAccountFactory } from "./interfaces/IKernelFactory.sol";
import { IKernel } from "./interfaces/IKernel.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ENTRYPOINT_ADDR } from "../../test/predeploy/EntryPoint.sol";
import { ValidatorLib } from "./lib/ValidationTypeLib.sol";
import { ValidationId } from "./types/Types.sol";
import { IValidator, IHook } from "./interfaces/IERC7579Modules.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { MockHookMultiPlexer } from "src/Mocks.sol";
import { KernelPrecompiles } from "src/test/precompiles/KernelPrecompiles.sol";

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

    function setHookMultiPlexer(address hook) public {
        hookMultiPlexer = MockHookMultiPlexer(hook);
    }
}
