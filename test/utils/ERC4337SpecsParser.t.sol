// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* solhint-disable no-global-import */
import { Test } from "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/test/RhinestoneModuleKit.sol";
import "forge-std/console2.sol";
import { writeSimulateUserOp } from "src/test/utils/Log.sol";
/* solhint-enable no-global-import */

contract SpecsTestValidator {
    struct DataStruct {
        uint256 data1;
        uint256 data2;
    }

    mapping(address => uint256) data;
    mapping(uint256 => mapping(address => uint256)) nestedData;
    mapping(uint256 => mapping(address => DataStruct)) nestedDataStruct;

    function setData(address addr, uint256 value) public {
        data[addr] = value;
    }

    function setNestedData(address addr, uint256 value) public {
        nestedData[value][addr] = value;
    }

    function setNestedDataStruct(address addr, uint256 value) public {
        nestedDataStruct[value][addr] = DataStruct({ data1: value, data2: value });
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

        console2.log(validators[0].module);

        // Setup account
        instance = makeRhinestoneAccount("account1", validators, executors, hook, fallBack);
        vm.deal(instance.account, 1000 ether);
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

        // Simulate userOperation
        writeSimulateUserOp(true);

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

        // Simulate userOperation
        writeSimulateUserOp(true);

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

        // Simulate userOperation
        writeSimulateUserOp(true);

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
}
