// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { BaseTest } from "test/BaseTest.t.sol";
import { IERC7579Account } from "src/accounts/common/interfaces/IERC7579Account.sol";
import { IERC7579Bootstrap } from "src/accounts/erc7579/interfaces/IERC7579Bootstrap.sol";
import { ExampleFactory } from "src/integrations/registry/ExampleFactory.sol";
import { ModuleKitHelpers } from "src/ModuleKit.sol";
import { IStakeManager } from "src/external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "src/deployment/predeploy/EntryPoint.sol";
import { getHelper } from "src/test/utils/Storage.sol";
import { AccountType } from "src/test/RhinestoneModuleKit.sol";
import { ERC7579Precompiles } from "src/deployment/precompiles/ERC7579Precompiles.sol";

contract ExampleFactoryTest is BaseTest, ERC7579Precompiles {
    using ModuleKitHelpers for *;

    IERC7579Account implementation;
    IERC7579Bootstrap bootstrap;
    ExampleFactory factory;

    function setUp() public override {
        super.setUp();

        implementation = deployERC7579Account();
        vm.label(address(implementation), "AccountSingleton");
        bootstrap = deployERC7579Bootstrap();
        vm.label(address(bootstrap), "Bootstrap");
        address[] memory trustedAttesters = new address[](2);
        trustedAttesters[0] = makeAddr("attester1");
        trustedAttesters[1] = makeAddr("attester2");
        uint8 threshold = 2;

        factory = new ExampleFactory(
            address(implementation),
            address(bootstrap),
            address(instance.aux.registry),
            trustedAttesters,
            threshold
        );
        vm.label(address(factory), "ExampleFactory");

        vm.deal(address(factory), 10 ether);
        vm.prank(address(factory));
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
    }

    function test_createAccount() public {
        address account =
            factory.createAccount(keccak256("1"), address(instance.defaultValidator), "");
        assertTrue(account != address(0));
        assertEq(IERC7579Account(payable(account)).accountId(), "uMSA.advanced/withHook.v0.1");
    }

    function test_userOpFlow() public {
        bytes32 salt = bytes32(bytes("newAccount"));
        address account = factory.getAddress(salt, address(instance.defaultValidator), "");
        bytes memory initCode = factory.getInitCode(salt, address(instance.defaultValidator), "");
        address erc7579Helper = ModuleKitHelpers.getHelper(AccountType.DEFAULT);

        instance = makeAccountInstance({
            salt: salt,
            helper: erc7579Helper,
            account: account,
            initCode: initCode
        });

        address target = makeAddr("target");
        uint256 value = 1 ether;

        instance.exec({ target: target, value: value, callData: "" });

        assertTrue(target.balance == value);
    }
}
