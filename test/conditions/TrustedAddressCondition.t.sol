// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import {
    ComposableConditionManager,
    ConditionConfig,
    ICondition
} from "../../src/core/ComposableCondition.sol";
import { MockCondition } from "../../src/test/mocks/MockCondition.sol";
import { MockRegistry } from "../../src/test/mocks/MockRegistry.sol";
import { TrustedAddressesCondition } from
    "../../src/modulekit/conditions/TrustedAddressesCondition.sol";

import { Merkle } from "murky/Merkle.sol";

contract TrustedAddressConditionTest is Test {
    ComposableConditionManager conditionManager;
    MockRegistry registry;
    TrustedAddressesCondition trustedAddressCondition;

    address owner;
    Merkle m;

    function setUp() public {
        m = new Merkle();
        owner = makeAddr("owner");
        registry = new MockRegistry();
        conditionManager = new ComposableConditionManager(registry);
        trustedAddressCondition = new  TrustedAddressesCondition(owner);
    }

    function updateTrustedAddresses(address[] memory trustedAddresses)
        private
        returns (bytes32[] memory leaves)
    {
        uint256 length = trustedAddresses.length;
        leaves = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            leaves[i] = trustedAddressCondition.leaf(trustedAddresses[i]);
        }

        trustedAddressCondition.setTrustedAddressesRoot(m.getRoot(leaves));
    }

    function test_checkCondition_directly() public {
        address[] memory trustedAddresses = new address[](2);
        trustedAddresses[0] = makeAddr("trustedAddress1");
        trustedAddresses[1] = makeAddr("trustedAddress2");

        vm.startPrank(owner);
        bytes32[] memory leaves = updateTrustedAddresses(trustedAddresses);
        vm.stopPrank();

        bytes32[] memory proof = m.getProof(leaves, 1);

        assertTrue(
            trustedAddressCondition.checkCondition(
                address(0),
                address(0),
                abi.encode(
                    TrustedAddressesCondition.Params({
                        proof: proof,
                        checkAddress: trustedAddresses[1]
                    })
                ),
                bytes("")
            )
        );

        assertFalse(
            trustedAddressCondition.checkCondition(
                address(0),
                address(0),
                abi.encode(
                    TrustedAddressesCondition.Params({
                        proof: proof,
                        checkAddress: makeAddr("notTrustedAddress")
                    })
                ),
                bytes("")
            )
        );
    }
}
