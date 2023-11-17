// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "src/test/utils/kernel-base/RhinestoneModuleKit.sol";
import "src/test/utils/kernel-base/IKernel.sol";

contract Target {
    uint256 value;

    function set(uint256 _value) public returns (uint256) {
        value = _value;
        return _value;
    }
}

contract DefaultKernelValidator is IKernelValidator {
    function enable(bytes calldata _data) external payable override { }

    function disable(bytes calldata _data) external payable override { }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingFunds
    )
        external
        payable
        override
        returns (ValidationData)
    { }

    function validateSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        override
        returns (ValidationData)
    { }

    function validCaller(
        address caller,
        bytes calldata data
    )
        external
        view
        override
        returns (bool)
    {
        return true;
    }
}

contract KernelRhinestoneModuleKitTest is RhinestoneModuleKit, Test {
    RhinestoneAccount instance;
    Target target;
    DefaultKernelValidator validator;

    function setUp() public {
        target = new Target();
        instance = makeRhinestoneAccount("1");

        validator = new DefaultKernelValidator();

        vm.deal(instance.account, 1 ether);
    }

    function test_something() public {
        assertTrue(address(instance.account) != address(0));
    }

    function test_exec() public {
        vm.prank(address(entrypoint));
        IKernel(instance.account).setDefaultValidator(IKernelValidator(address(validator)), "");

        // IKernel(instance.account).execute(
        //     address(target), 0, abi.encodeCall(Target.set, (1336)), Operation.Call
        // );
    }
}
