// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Modules.sol";
import "@rhinestone/modulekit/src/Helpers.sol";

import { SubValidator } from "src/StatelessValidation/SubValidator.sol";
import { MultiPlexer } from "src/StatelessValidation/MultiPlexer.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { Solarray } from "solarray/Solarray.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK
} from "@rhinestone/modulekit/src/external/ERC7579.sol";

contract StatelessValidationTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;

    AccountInstance internal instance;

    MockERC20 internal token;

    address internal recipient;

    Account internal signer1;
    Account internal signer2;

    MultiPlexer internal multiPlexer;
    SubValidator internal subValidator1;
    SubValidator internal subValidator2;

    function setUp() public {
        instance = makeAccountInstance("1");
        recipient = makeAddr("recipient");

        signer1 = makeAccount("signer1");
        signer2 = makeAccount("signer2");

        multiPlexer = new MultiPlexer();
        subValidator1 = new SubValidator();
        subValidator2 = new SubValidator();

        token = new MockERC20("USDC", "USDC", 18);

        MultiPlexer.Param[] memory params = new MultiPlexer.Param[](2);

        params[0] = MultiPlexer.Param({
            statelessValidator: address(subValidator1),
            validationData: abi.encode(address(signer1.addr))
        });
        params[1] = MultiPlexer.Param({
            statelessValidator: address(subValidator2),
            validationData: abi.encode(address(signer2.addr))
        });

        instance.installModule(MODULE_TYPE_VALIDATOR, address(multiPlexer), abi.encode(params));
        token.mint(instance.account, 1_000_000);
        vm.deal(instance.account, 1000 ether);
    }

    function test_validateUserOpWithData() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: recipient,
            value: 1 ether,
            callData: "",
            txValidator: address(multiPlexer)
        });

        // vm.expectRevert();
        // userOpData.execUserOps();

        bytes memory sig1 = ecdsaSign(signer1.key, userOpData.userOpHash);
        bytes memory sig2 = ecdsaSign(signer2.key, userOpData.userOpHash);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = sig1;
        signatures[1] = sig2;

        userOpData.userOp.signature = abi.encode(signatures);
        userOpData.execUserOps();

        assertEq(recipient.balance, 1 ether);
    }
}
