// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../../utils/safe-base/AccountFactory.sol";
import "../../utils/safe-base/RhinestoneUtil.sol";

import {SimpleValidator} from "../../../src/modules/validators/SimpleValidator.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SimpleValidatorTest is AccountFactory, Test {
    using RhinestoneUtil for AccountInstance;
    using ECDSA for bytes32;

    AccountInstance smartAccount;
    SimpleValidator simpleValidator;

    function setUp() public {
        // Setup account
        smartAccount = newInstance("1");
        vm.deal(smartAccount.account, 10 ether);

        // Setup validator
        simpleValidator = new SimpleValidator();
        (address owner,) = makeAddrAndKey("owner");
        simpleValidator.setOwner(address(smartAccount.account), owner);

        // Add validator to account
        smartAccount.addValidator(address(simpleValidator));
    }

    function testSendEth() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        uint8 operation = 0;

        // Create signature
        (, uint256 key) = makeAddrAndKey("owner");
        bytes32 hash =
            smartAccount.getUserOpHash({target: receiver, value: value, callData: callData, operation: operation});
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // Create userOperation
        smartAccount.exec4337({
            target: receiver,
            value: value,
            callData: callData,
            operation: operation,
            signature: signature
        });

        // Validate userOperation
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testRecoverValidator() public {
        address newOwner = makeAddr("newOwner");
        // Recover validator
        vm.prank(smartAccount.account);
        simpleValidator.recoverValidator(address(0), bytes(""), abi.encode(newOwner));

        // Validate recovery success
        assertEq(simpleValidator.owners(address(smartAccount.account)), newOwner, "Validator should be recovered");
    }

    function test1271Signature() public {
        // Create signature
        (address owner, uint256 key) = makeAddrAndKey("owner");
        bytes32 hash = keccak256("Test sinature");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(r, s, v);

        // Validate signature
        vm.prank(smartAccount.account);
        bytes4 returnValue = simpleValidator.isValidSignature(hash, signature);

        // Validate signature success
        assertEq(
            returnValue,
            bytes4(0x1626ba7e), // EIP1271_MAGIC_VALUE
            "Signature should be valid"
        );
    }
}
