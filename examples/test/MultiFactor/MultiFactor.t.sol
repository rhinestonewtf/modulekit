// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Modules.sol";
import "modulekit/src/Mocks.sol";
import "modulekit/src/interfaces/IERC1271.sol";

import { MultiFactor } from "src/MultiFactor/MultiFactor.sol";
import { MultiFactorLib } from "src/MultiFactor/MultiFactorLib.sol";
import "src/MultiFactor/DataTypes.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Solarray } from "solarray/Solarray.sol";

import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";
import { DemoValidator } from "./StatelessValidator.sol";

contract MultiFactorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;
    using MultiFactorLib for *;

    AccountInstance internal instance;

    MockTarget internal target;
    MockERC20 internal token;
    MockRegistry internal registry;

    DemoValidator internal validator1;
    DemoValidator internal validator2;

    Account internal signer;

    MultiFactor internal mfa;

    address internal recipient;

    function setUp() public {
        instance = makeAccountInstance("1");
        vm.deal(instance.account, 1 ether);

        signer = makeAccount("signer");
        registry = new MockRegistry();

        mfa = new MultiFactor(registry);

        validator1 = new DemoValidator();
        validator2 = new DemoValidator();

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        Validator[] memory validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator1))),
            data: hex"41414141"
        });

        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator2))),
            data: hex"41414141"
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mfa),
            data: abi.encodePacked(uint8(2), abi.encode(validators))
        });
    }

    function test_packing(address validator, bytes12 id) public pure {
        validator = address(0x41424343);
        id = bytes12(uint96(type(uint96).max));
        bytes32 packed = MultiFactorLib.pack(validator, validatorId.wrap(id));

        (address _validator, validatorId _id) = MultiFactorLib.unpack(packed);
        assertEq(validator, _validator);
        assertEq(id, validatorId.unwrap(_id));
    }

    function test_addValidator(validatorId id) public {
        vm.startPrank(instance.account);

        bytes memory data = hex"434343434343";
        mfa.setValidator(address(validator1), id, data);
        vm.stopPrank();

        assertTrue(mfa.isSubValidator(instance.account, address(validator1), id));
    }

    function test_rmValidator(validatorId id) public {
        test_addValidator(id);
        vm.prank(instance.account);
        mfa.rmValidator(address(validator1), id);
        assertFalse(mfa.isSubValidator(instance.account, address(validator1), id));
    }

    function test_Transaction() public {
        Validator[] memory validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator1))),
            data: hex"41414141"
        });

        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator2))),
            data: hex"41414141"
        });

        // prepare userOp
        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(MockERC20.transfer.selector, recipient, 10 ether),
            txValidator: address(mfa)
        });

        userOpData.userOp.signature = abi.encode(validators);

        userOpData.execUserOps();

        assertEq(token.balanceOf(recipient), 10 ether);
    }

    function test_ERC1271() public {
        Validator[] memory validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator1))),
            data: hex"41414141"
        });

        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(1), address(validator2))),
            data: hex"41414141"
        });

        bytes4 magicValue = IERC1271(instance.account).isValidSignature(
            bytes32(hex"4141"), abi.encodePacked(address(mfa), abi.encode(validators))
        );

        assertEq(magicValue, IERC1271.isValidSignature.selector);
    }
}
