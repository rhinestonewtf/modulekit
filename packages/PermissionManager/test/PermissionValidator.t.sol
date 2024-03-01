// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@rhinestone/modulekit/src/Core.sol";

import { MODULE_TYPE_VALIDATOR } from "@rhinestone/modulekit/src/external/ERC7579.sol";

import "src/PermissionValidator.sol";
import "src/policies/SudoPolicy.sol";
import "src/signers/ECDSASigner.sol";

contract PermissionValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    Account internal signer = makeAccount("signer");
    PermissionValidator internal permissionValidator;

    SudoPolicy internal sudoPolicy;
    ECDSASigner internal ecdsaSigner;

    bytes32 permissionId;

    function setUp() public {
        vm.warp(123_123_123);
        instance = makeAccountInstance("instance");
        vm.deal(instance.account, 100 ether);

        permissionValidator = new PermissionValidator();
        vm.label(address(permissionValidator), "PermissionValidator");
        sudoPolicy = new SudoPolicy();
        vm.label(address(sudoPolicy), "SudoPolicy");
        ecdsaSigner = new ECDSASigner();
        vm.label(address(ecdsaSigner), "ECDSASigner");

        _setupPermission();
        instance.installModule({
            module: address(permissionValidator),
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            data: ""
        });
    }

    function _setupPermission() internal {
        vm.prank(instance.account);

        bytes12 flag = MAX_FLAG;
        bytes memory signerData = abi.encodePacked(signer.addr);
        PolicyConfig[] memory policyConfigs = new PolicyConfig[](1);
        policyConfigs[0] = PolicyConfigLib.pack({ addr: IPolicy(address(sudoPolicy)), flag: flag });
        bytes[] memory policyDatas = new bytes[](1);
        policyDatas[0] = hex"41414141";
        permissionId = permissionValidator.registerPermission({
            nonce: 0,
            flag: flag,
            signer: ISigner(address(ecdsaSigner)),
            validAfter: ValidAfter.wrap(uint48(block.timestamp - 1)),
            validUntil: ValidUntil.wrap(type(uint48).max),
            policy: policyConfigs,
            signerData: signerData,
            policyData: policyDatas
        });
    }

    function test_sendETH() public {
        address target = makeAddr("target");
        uint256 balanceBefore = target.balance;
        uint256 value = 1 ether;
        bytes memory callData = "";

        // instance.exec({ target: address(target), value: value, callData: callData });

        UserOpData memory userOpData =
            instance.getExecOps(target, value, callData, address(permissionValidator));
        // sign userOp with default signature
        userOpData.userOp.signature = abi.encodePacked(
            permissionId, ecdsaSign(signer.key, ECDSA.toEthSignedMessageHash(userOpData.userOpHash))
        );

        // send userOp to entrypoint
        userOpData.execUserOps();
        assertEq(target.balance, balanceBefore + value);
    }
}
