// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import {
    Rhinestone4337,
    ExecutorAction,
    ERC1271_MAGICVALUE
} from "../../../src/core/Rhinestone4337.sol";
import { MockRegistry, IERC7484Registry } from "../../../src/test/mocks/MockRegistry.sol";
import { ENTRYPOINT_ADDR } from "../../../src/test/utils/dependencies/EntryPoint.sol";
import { MockValidator } from "../../../src/test/mocks/MockValidator.sol";
import { SENTINEL, ZERO_ADDRESS } from "sentinellist/src/SentinelList.sol";
import { getEmptyUserOp, UserOperation } from "../../TestUtils.t.sol";

contract FalseValidator {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        returns (uint256)
    {
        return 1;
    }

    function isValidSignature(
        bytes32 dataHash,
        bytes calldata signature
    )
        public
        view
        returns (bytes4)
    {
        return 0xffffffff;
    }
}

contract Rhinestone4337Instance is Rhinestone4337 {
    constructor(
        address entryPoint,
        IERC7484Registry registry
    )
        Rhinestone4337(entryPoint, registry)
    { }

    function _execTransationOnSmartAccount(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        override
        returns (bool success, bytes memory)
    {
        bytes memory callData =
            abi.encodeWithSelector(Rhinestone4337Test.executeTarget.selector, to, value, data);
        safe.call(callData);
        // success = ISafe(safe).execTransactionFromModule(to, value, data, 0);
    }

    function _execTransationOnSmartAccount(
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bool success, bytes memory)
    {
        // address safe = _msgSender();
        // return _execTransationOnSmartAccount(safe, to, value, data);
        return (true, "");
    }

    function _execDelegateCallOnSmartAccount(
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bool success, bytes memory)
    {
        // address safe = _msgSender();
        // success = ISafe(safe).execTransactionFromModule(to, value, data, 1);
    }

    function _msgSender() internal pure override returns (address sender) {
        // The assembly code is more direct than the Solidity version using `abi.decode`.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    function _prefundEntrypoint(
        address safe,
        address entryPoint,
        uint256 requiredPrefund
    )
        internal
        virtual
        override
    {
        // ISafe(safe).execTransactionFromModule(entryPoint, requiredPrefund, "", 0);
    }

    receive() external payable { }
}

contract Rhinestone4337Test is Test {
    Rhinestone4337Instance rhinestone4337;

    MockRegistry registry;
    MockValidator validator;
    FalseValidator falseValidator;

    address account = makeAddr("account");
    address attester = makeAddr("attester");

    function setUp() public {
        registry = new MockRegistry();
        validator = new MockValidator();
        falseValidator = new FalseValidator();
        rhinestone4337 = new Rhinestone4337Instance(ENTRYPOINT_ADDR, registry);

        vm.prank(account);
        rhinestone4337.init(address(validator), attester, bytes(""));
    }

    function testAddValidator() public {
        address secondValidator = makeAddr("secondValidator");

        vm.prank(account);
        rhinestone4337.addValidator(secondValidator);

        assertTrue(rhinestone4337.isValidatorEnabled(account, secondValidator));
    }

    function testRemoveValidator() public {
        address secondValidator = makeAddr("secondValidator");

        vm.prank(account);
        rhinestone4337.addValidator(secondValidator);

        assertTrue(rhinestone4337.isValidatorEnabled(account, secondValidator));

        vm.prank(account);
        rhinestone4337.removeValidator(SENTINEL, secondValidator);

        assertFalse(rhinestone4337.isValidatorEnabled(account, secondValidator));
    }

    function testGetValidatorPaginated() public {
        address secondValidator = makeAddr("secondValidator");
        address thirdValidator = makeAddr("thirdValidator");

        vm.startPrank(account);
        rhinestone4337.addValidator(secondValidator);
        rhinestone4337.addValidator(thirdValidator);
        vm.stopPrank();

        uint256 length = 2;

        (address[] memory validators, address next) =
            rhinestone4337.getValidatorPaginated(SENTINEL, length, account);

        assertEq(validators.length, length);
        assertEq(validators[0], thirdValidator);
        assertEq(validators[1], secondValidator);
        assertEq(next, secondValidator);

        // @Todo: is this a bug?
        // length = 1;

        // (validators, next) = rhinestone4337.getValidatorPaginated(next, length, account);

        // assertEq(validators.length, length);
        // assertEq(validators[0], thirdValidator);
    }

    function testGetValidatorPaginated__RevertWhen__LengthZero() public {
        uint256 length = 0;

        vm.expectRevert();
        rhinestone4337.getValidatorPaginated(SENTINEL, length, account);
    }

    function testGetValidatorPaginated__RevertWhen__InvalidStart() public {
        uint256 length = 2;

        vm.expectRevert();
        rhinestone4337.getValidatorPaginated(makeAddr("invalidStart"), length, account);
    }

    function testValidateUserOp() public {
        UserOperation memory userOp = getEmptyUserOp();
        userOp.sender = account;

        bytes memory sig = abi.encode(keccak256("signature"));
        userOp.signature = abi.encode(sig, address(validator));

        bytes memory callData = abi.encodeWithSelector(
            Rhinestone4337.validateUserOp.selector, userOp, keccak256("invalidCaller"), 0
        );
        callData = abi.encodePacked(callData, ENTRYPOINT_ADDR);

        vm.prank(account);
        (bool success, bytes memory returnData) = address(rhinestone4337).call(callData);
        assertTrue(success);
        assertEq(returnData, abi.encode(0));
    }

    function testValidateUserOp__RevertWhen__InvalidCaller() public {
        UserOperation memory userOp = getEmptyUserOp();
        userOp.sender = account;

        vm.expectRevert("Invalid Caller");
        rhinestone4337.validateUserOp(userOp, keccak256("invalidCaller"), 0);
    }

    function testValidateUserOp__RevertWhen__InvalidEntryPoint() public {
        UserOperation memory userOp = getEmptyUserOp();
        userOp.sender = account;

        vm.expectRevert("Unsupported entry point");
        vm.prank(account);
        rhinestone4337.validateUserOp(userOp, keccak256("invalidCaller"), 0);
    }

    function testValidateUserOp__RevertWhen__ValidatorNotEnabled() public {
        address invalidValidator = makeAddr("invalidValidator");
        UserOperation memory userOp = getEmptyUserOp();
        userOp.sender = account;

        bytes memory sig = abi.encode(keccak256("signature"));
        userOp.signature = abi.encodePacked(invalidValidator, sig);

        bytes memory callData = abi.encodeWithSelector(
            Rhinestone4337.validateUserOp.selector, userOp, keccak256("invalidCaller"), 0
        );
        callData = abi.encodePacked(callData, ENTRYPOINT_ADDR);

        vm.prank(account);
        (bool success,) = address(rhinestone4337).call(callData);
        assertFalse(success);
    }

    function testValidateUserOp__RevertWhen__InvalidSignature() public {
        vm.prank(account);
        rhinestone4337.addValidator(address(falseValidator));

        assertTrue(rhinestone4337.isValidatorEnabled(account, address(falseValidator)));

        UserOperation memory userOp = getEmptyUserOp();
        userOp.sender = account;

        bytes memory sig = abi.encode(keccak256("signature"));
        userOp.signature = abi.encodePacked(address(falseValidator), sig);

        bytes memory callData = abi.encodeWithSelector(
            Rhinestone4337.validateUserOp.selector, userOp, keccak256("invalidCaller"), 0
        );
        callData = abi.encodePacked(callData, ENTRYPOINT_ADDR);

        vm.prank(account);
        (bool success,) = address(rhinestone4337).call(callData);
        assertFalse(success);
    }

    function testExecuteBatch() public {
        // reset hashes
        hashes = new bytes32[](0);
        assertEq(hashes.length, 0);

        address to = makeAddr("to");
        uint256 value = 0;
        bytes memory data = abi.encode(true);

        address to2 = makeAddr("to2");
        uint256 value2 = 0;
        bytes memory data2 = abi.encode(false);

        address[] memory targets = new address[](2);
        targets[0] = to;
        targets[1] = to2;

        uint256[] memory values = new uint256[](2);
        values[0] = value;
        values[1] = value2;

        bytes[] memory datas = new bytes[](2);
        datas[0] = data;
        datas[1] = data2;

        bytes memory callData =
            abi.encodeWithSelector(Rhinestone4337.executeBatch.selector, targets, values, datas);
        callData = abi.encodePacked(callData, ENTRYPOINT_ADDR);

        address(rhinestone4337).call(callData);

        assertEq(hashes.length, 2);
        assertEq(hashes[0], keccak256(abi.encode(to, value, data)));
        assertEq(hashes[1], keccak256(abi.encode(to2, value2, data2)));
    }

    // function testExecute() public {
    //     // reset hashes
    //     hashes = new bytes32[](0);
    //     assertEq(hashes.length, 0);

    //     address to = makeAddr("to");
    //     uint256 value = 0;
    //     bytes memory data = abi.encode(true);

    //     ExecutorAction memory action = ExecutorAction({ to: payable(to), value: value, data: data });

    //     rhinestone4337.execute(action);

    //     assertEq(hashes.length, 1);
    //     assertEq(hashes[0], keccak256(abi.encode(to, value, data)));
    // }

    function testIsValidSignature() public {
        bytes32 dataHash = keccak256("dataHash");
        bytes memory sig = abi.encode("signature");
        bytes memory signature = abi.encode(sig, address(validator));

        vm.prank(account);
        bytes4 returnData = rhinestone4337.isValidSignature(dataHash, signature);
        assertEq(returnData, ERC1271_MAGICVALUE);
    }

    function testIsValidSignature__InvalidSignature() public {
        vm.prank(account);
        rhinestone4337.addValidator(address(falseValidator));

        assertTrue(rhinestone4337.isValidatorEnabled(account, address(falseValidator)));

        bytes32 dataHash = keccak256("dataHash");
        bytes memory sig = abi.encode("signature");
        bytes memory signature = abi.encode(sig, address(falseValidator));

        vm.prank(account);
        bytes4 returnData = rhinestone4337.isValidSignature(dataHash, signature);
        assertEq(returnData, bytes4(0xffffffff));
    }

    function testIsValidSignature__RevertWhen__ValidatorNotEnabled() public {
        address invalidValidator = makeAddr("invalidValidator");
        bytes32 dataHash = keccak256("dataHash");
        bytes memory sig = abi.encode("signature");
        bytes memory signature = abi.encode(sig, address(invalidValidator));

        vm.prank(account);
        vm.expectRevert("Validator not enabled");
        rhinestone4337.isValidSignature(dataHash, signature);
    }

    // Helpers
    bytes32[] public hashes;

    function executeTarget(address to, uint256 value, bytes memory data) public {
        bytes32 execHash = keccak256(abi.encode(to, value, data));
        hashes.push(execHash);
    }

    error Executed(bytes32 hash);
}
