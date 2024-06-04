pragma solidity ^0.8.23;

import { KernelFactory as KernelAccountFactory } from "kernel/factory/KernelFactory.sol";
import { Kernel } from "kernel/Kernel.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { ENTRYPOINT_ADDR } from "../../test/predeploy/EntryPoint.sol";
import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationId } from "kernel/types/Types.sol";
import { IValidator, IHook } from "kernel/interfaces/IERC7579Modules.sol";

abstract contract KernelFactory {
    KernelAccountFactory internal factory;
    Kernel internal kernalImpl;

    function initKernel() internal {
        kernalImpl = new Kernel(IEntryPoint(ENTRYPOINT_ADDR));
        factory = new KernelAccountFactory(address(kernalImpl));
    }

    function createKernel(bytes memory data, bytes32 salt) public returns (address account) {
        account = factory.createAccount(data, salt);
    }

    function getAddressKernel(
        bytes memory data,
        bytes32 salt
    )
        public
        view
        virtual
        returns (address)
    {
        return factory.getAddress(data, salt);
    }

    function getInitDataKernel(
        address validator,
        bytes memory initData
    )
        public
        pure
        returns (bytes memory init)
    {
        ValidationId rootValidator = ValidatorLib.validatorToIdentifier(IValidator(validator));

        init = abi.encodeCall(Kernel.initialize, (rootValidator, IHook(address(0)), initData, ""));
    }
}
