// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Modules.sol";
import "modulekit/src/Mocks.sol";

import { MultiFactor, ECDSAFactor } from "src/MultiFactor/MultiFactor.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Solarray } from "solarray/Solarray.sol";

import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";

contract DemoValidator is MockValidator {
    mapping(address account => bool isInitialized) public initialized;

    error AlreadyInstalled();

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) revert("empty data");
        // TODO:
        // if (initialized[msg.sender]) revert AlreadyInstalled();
        initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata data) external override {
        if (data.length == 0) revert("empty data");
        initialized[msg.sender] = false;
    }
}

contract MultiFactorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;

    AccountInstance internal instance;

    MockTarget internal target;
    MockERC20 internal token;

    DemoValidator internal validator1;
    DemoValidator internal validator2;

    Account internal signer;

    MultiFactor internal mfa;

    address internal recipient;

    function setUp() public {
        instance = makeAccountInstance("1");
        vm.deal(instance.account, 1 ether);

        signer = makeAccount("signer");

        mfa = new MultiFactor();

        validator1 = new DemoValidator();
        validator2 = new DemoValidator();

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
    }

    modifier initMFA() {
        initAccount();
        _;
    }

    function initAccount() internal {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mfa),
            data: ""
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(mfa), data: "" });
        configMFA();
    }

    function configMFA() public {
        address[] memory validators = Solarray.addresses(address(validator1), address(validator2));
        bytes[] memory initDatas = Solarray.bytess(abi.encode(true), abi.encode(true));
        bytes[] memory deInitDatas = Solarray.bytess("", "");
        vm.prank(instance.account);
        mfa.setConfig(validators, deInitDatas, initDatas, 2);

        assertTrue(validator1.initialized(instance.account));
        assertTrue(validator2.initialized(instance.account));
    }

    function test_Transaction() public initMFA {
        // prepare signature
        uint256[] memory validatorIds = Solarray.uint256s(0, 1);
        bytes[] memory signatures = Solarray.bytess("", "");

        bytes memory signature = abi.encode(validatorIds, signatures);

        // prepare userOp
        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(MockERC20.transfer.selector, recipient, 10 ether),
            txValidator: address(mfa)
        });

        userOpData.userOp.signature = signature;

        userOpData.execUserOps();

        assertEq(token.balanceOf(recipient), 10 ether);
    }

    function init_localECDSA() public {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mfa),
            data: ""
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(mfa), data: "" });
        address[] memory validators = Solarray.addresses(address(mfa), address(validator2));
        ECDSAFactor.FactorConfig memory conf = ECDSAFactor.FactorConfig({
            signer: signer.addr,
            validAfter: 0,
            validBefore: type(uint48).max
        });
        bytes[] memory initDatas = Solarray.bytess(abi.encode(conf), abi.encode(true));
        bytes[] memory deInitDatas = Solarray.bytess("", "");
        vm.prank(instance.account);
        mfa.setConfig(validators, deInitDatas, initDatas, 2);
    }

    function signHash(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ECDSA.toEthSignedMessageHash(digest));
        return abi.encodePacked(r, s, v);
    }

    function test_withLocalEC() public {
        init_localECDSA();
        // prepare signature
        uint256[] memory validatorIds = Solarray.uint256s(0, 1);

        // prepare userOp
        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(MockERC20.transfer.selector, recipient, 10 ether),
            txValidator: address(mfa)
        });
        bytes[] memory signatures = Solarray.bytess(signHash(signer.key, userOpData.userOpHash), "");

        bytes memory signature = abi.encode(validatorIds, signatures);

        userOpData.userOp.signature = signature;

        userOpData.execUserOps();

        assertEq(token.balanceOf(recipient), 10 ether);
    }
}
