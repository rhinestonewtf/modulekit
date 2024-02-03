// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* solhint-disable no-global-import */
import { Test } from "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/test/RhinestoneModuleKit.sol";
import "forge-std/console2.sol";
import { writeSimulateUserOp } from "src/test/utils/Log.sol";
import { ERC4337SpecsParser } from "src/test/utils/ERC4337Helpers.sol";
/* solhint-enable no-global-import */

contract SpecsTestValidator {
    struct DataStruct {
        uint256 data1;
        uint256 data2;
    }

    uint256 data;
    mapping(address => uint256) singleData;
    mapping(uint256 => mapping(address => uint256)) nestedData;
    mapping(address => mapping(uint256 => uint256)) nestedDataReverse;
    mapping(uint256 => mapping(address => DataStruct)) nestedDataStruct;

    function setData(uint256 value) public {
        data = value;
    }

    function setDataIntoSlot(address addr, uint256 value) public {
        assembly {
            sstore(addr, value)
        }
    }

    function setData(address addr, uint256 value) public {
        singleData[addr] = value;
    }

    function setNestedData(address addr, uint256 value) public {
        nestedData[value][addr] = value;
    }

    function setNestedDataReverse(address addr, uint256 value) public {
        nestedDataReverse[addr][value] = value;
    }

    function setNestedDataStruct(address addr, uint256 value) public {
        nestedDataStruct[value][addr] = DataStruct({ data1: value, data2: value });
    }

    function setNestedDataWithOffset(address addr, uint256 value, uint256 offset) public {
        bytes32 slot;
        assembly {
            slot := singleData.slot
        }
        bytes32 _slot = keccak256(abi.encode(addr, slot));
        bytes32 offsetSlot = bytes32(uint256(_slot) + offset);
        assembly {
            sstore(offsetSlot, value)
        }
    }

    function onInstall(bytes memory) external {
        // Do nothing
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256)
    {
        uint256 mode = uint256(bytes32(userOp.signature[0:32]));
        if (mode == 1) {
            setData(msg.sender, 1);
        } else if (mode == 2) {
            setNestedData(msg.sender, 2);
        } else if (mode == 3) {
            setNestedDataStruct(msg.sender, 3);
        } else if (mode == 4) {
            setData(address(1), 4);
        } else if (mode == 5) {
            setNestedData(address(1), 5);
        } else if (mode == 6) {
            setData(6);
        } else if (mode == 7) {
            setNestedDataReverse(address(1), 7);
        } else if (mode == 8) {
            setNestedDataWithOffset(msg.sender, 8, 128);
        } else if (mode == 9) {
            setNestedDataWithOffset(msg.sender, 9, 129);
        } else if (mode == 10) {
            setDataIntoSlot(msg.sender, 10);
        }
        return 0;
    }
}

contract ERC4337SpecsParserTest is Test, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    RhinestoneAccount internal instance;
    SpecsTestValidator internal validator;

    function setUp() public {
        // Setup mock specs
        validator = new SpecsTestValidator();
        vm.label(address(validator), "SpecsTestValidator");

        // Account config
        ERC7579BootstrapConfig[] memory validators = makeBootstrapConfig(address(validator), "");
        ERC7579BootstrapConfig[] memory executors = _emptyConfigs();
        ERC7579BootstrapConfig memory hook = _emptyConfig();
        ERC7579BootstrapConfig memory fallBack = _emptyConfig();

        // Setup account
        instance = makeRhinestoneAccount("account1", validators, executors, hook, fallBack);
        vm.deal(instance.account, 1000 ether);

        // Simulate userOperation
        writeSimulateUserOp(true);
    }

    function exec(address receiver, bytes memory callData) internal {
        // Create userOperation
        instance.exec({ target: receiver, callData: callData });
    }

    function testSingleMapping() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(1)));

        userOpData.execUserOps();
    }

    function testNestedMapping() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(2)));

        userOpData.execUserOps();
    }

    function testNestedMappingStruct() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(3)));

        userOpData.execUserOps();
    }

    function singleMapping__RevertWhen__InvalidKey() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(4)));

        userOpData.execUserOps();
    }

    function testSingleMapping__RevertWhen__InvalidKey() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.singleMapping__RevertWhen__InvalidKey.selector)
        );
        assertFalse(success);
    }

    function nestedMapping__RevertWhen__InvalidKey() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(5)));

        userOpData.execUserOps();
    }

    function testNestedMapping__RevertWhen__InvalidKey() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.nestedMapping__RevertWhen__InvalidKey.selector)
        );
        assertFalse(success);
    }

    function simpleStorage__RevertWhen__InvalidSlot() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(6)));

        userOpData.execUserOps();
    }

    function testSimpleStorage__RevertWhen__InvalidSlot() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.simpleStorage__RevertWhen__InvalidSlot.selector)
        );
        assertFalse(success);
    }

    function nestedMapping__RevertWhen__InvalidArgOrder() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(7)));

        userOpData.execUserOps();
    }

    function testNestedMapping__RevertWhen__InvalidArgOrder() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.nestedMapping__RevertWhen__InvalidArgOrder.selector)
        );
        assertFalse(success);
    }

    function testStructMapping__With__Offset() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(8)));

        userOpData.execUserOps();
    }

    function structMapping__RevertWhen__OutOfBounds() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(9)));

        userOpData.execUserOps();
    }

    function testStructMapping__RevertWhen__OutOfBounds() public {
        // vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.structMapping__RevertWhen__OutOfBounds.selector)
        );
        assertFalse(success);
    }

    function testSetDataIntoAccountSlot() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });

        userOpData.userOp.signature = abi.encodePacked(bytes32(uint256(10)));

        userOpData.execUserOps();
    }
}
