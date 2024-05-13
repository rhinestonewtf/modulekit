pragma solidity ^0.8.23;

import {KernelFactory} from "kernel/factory/KernelFactory.sol";
import {Kernel} from "kernel/Kernel.sol";
import {IEntryPoint} from "kernel/interfaces/IEntryPoint.sol";
import {ENTRYPOINT_ADDR} from "../../test/predeploy/EntryPoint.sol";

abstract contract Kernel7579Factory {
    KernelFactory internal factory;
    Kernel internal kernalImpl;
    constructor() {
        kernalImpl = new Kernel(IEntryPoint(ENTRYPOINT_ADDR));
        factory = new KernelFactory(address(kernalImpl));
    }

    function _createKernel(
        bytes memory data,
        bytes32 salt
    ) public returns (address account) {
        account = factory.createAccount(data, salt);
    }

    function getAddressKernel(
        bytes memory data,
        bytes32 salt
    ) public view virtual returns (address) {
        return factory.getAddress(data, salt);
    }
}
