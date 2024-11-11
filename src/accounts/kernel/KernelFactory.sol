pragma solidity >=0.8.0 <0.9.0;

import { KernelFactory as KernelAccountFactory } from "kernel/factory/KernelFactory.sol";
import { Kernel } from "kernel/Kernel.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { ENTRYPOINT_ADDR } from "../../test/predeploy/EntryPoint.sol";
import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationId } from "kernel/types/Types.sol";
import { IValidator, IHook } from "kernel/interfaces/IERC7579Modules.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { MockHookMultiPlexer } from "src/Mocks.sol";

contract KernelFactory is IAccountFactory {
    KernelAccountFactory internal factory;
    Kernel internal kernalImpl;
    MockHookMultiPlexer public hookMultiPlexer;

    function init() public override {
        kernalImpl = new Kernel(IEntryPoint(ENTRYPOINT_ADDR));
        factory = new KernelAccountFactory(address(kernalImpl));
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

    function getAddress(bytes32 salt, bytes memory data) public view override returns (address) {
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
            Kernel.initialize, (rootValidator, IHook(address(hookMultiPlexer)), initData, hex"00")
        );
    }

    function setHookMultiPlexer(address hook) public {
        hookMultiPlexer = MockHookMultiPlexer(hook);
    }
}
