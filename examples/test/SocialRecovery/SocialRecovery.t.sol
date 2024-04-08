// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Mocks.sol";

import { SocialRecovery } from "src/SocialRecovery/SocialRecovery.sol";
import { Solarray } from "solarray/Solarray.sol";

import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";

contract DemoValidator {
    uint256 counter;

    function onInstall(bytes calldata) external { }

    function count() public {
        counter++;
    }

    function getCount() public view returns (uint256) {
        return counter;
    }
}

contract SocialRecoveryTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;

    AccountInstance internal instance;

    MockTarget internal target;
    MockERC20 internal token;

    DemoValidator internal validator1;
    DemoValidator internal validator2;

    Account internal signer1;
    Account internal signer2;
    Account internal signer3;

    SocialRecovery internal socialRecovery;

    function setUp() public {
        instance = makeAccountInstance("1");
        vm.deal(instance.account, 1 ether);

        signer1 = makeAccount("signer1");
        signer2 = makeAccount("signer2");
        signer3 = makeAccount("signer3");

        socialRecovery = new SocialRecovery();

        validator1 = new DemoValidator();
        validator2 = new DemoValidator();

        address[] memory signers = Solarray.addresses(signer1.addr, signer2.addr, signer3.addr);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(socialRecovery),
            data: abi.encode(uint256(2), signers)
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator1),
            data: ""
        });
    }

    function sign(
        uint256[] memory signerPrivKeys,
        bytes32 dataHash
    )
        internal
        returns (bytes memory signatures)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        for (uint256 i; i < signerPrivKeys.length; i++) {
            uint256 privKey = signerPrivKeys[i];
            (v, r, s) = vm.sign(privKey, dataHash);
            signatures = abi.encodePacked(signatures, abi.encodePacked(r, s, v));
        }
    }

    function testRecover() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(validator1),
            value: 0,
            callData: abi.encodeWithSelector(DemoValidator.count.selector),
            txValidator: address(socialRecovery)
        });

        uint256[] memory privKeys = Solarray.uint256s(signer1.key, signer2.key);
        bytes memory signature = sign(privKeys, userOpData.userOpHash);
        userOpData.userOp.signature = signature;
        userOpData.execUserOps();

        assertEq(validator1.getCount(), 1);
    }

    function testRecover__RevertWhen__InvalidTarget() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(validator2),
            value: 0,
            callData: abi.encodeWithSelector(DemoValidator.count.selector),
            txValidator: address(socialRecovery)
        });

        uint256[] memory privKeys = Solarray.uint256s(signer1.key, signer2.key);
        bytes memory signature = sign(privKeys, userOpData.userOpHash);
        userOpData.userOp.signature = signature;
        vm.expectRevert();
        userOpData.execUserOps();
    }

    function testRecover__RevertWhen__InvalidSignatures() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(validator1),
            value: 0,
            callData: abi.encodeWithSelector(DemoValidator.count.selector),
            txValidator: address(socialRecovery)
        });

        uint256[] memory privKeys = Solarray.uint256s(signer1.key, uint256(3));
        bytes memory signature = sign(privKeys, userOpData.userOpHash);
        userOpData.userOp.signature = signature;
        vm.expectRevert();
        userOpData.execUserOps();
    }

    function testRecover__RevertWhen__SameGuardianUsed() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(validator1),
            value: 0,
            callData: abi.encodeWithSelector(DemoValidator.count.selector),
            txValidator: address(socialRecovery)
        });

        uint256[] memory privKeys = Solarray.uint256s(signer1.key, signer1.key);
        bytes memory signature = sign(privKeys, userOpData.userOpHash);
        userOpData.userOp.signature = signature;
        vm.expectRevert();
        userOpData.execUserOps();
    }
}
