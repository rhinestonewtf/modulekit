// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Modules.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@rhinestone/modulekit/src/core/ExtensibleFallbackHandler.sol";
import "@rhinestone/sessionkeymanager/src/ISessionValidationModule.sol";
import {
    SessionData,
    SessionKeyManagerLib
} from "@rhinestone/sessionkeymanager/src/SessionKeyManagerLib.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import { Solarray } from "solarray/Solarray.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { IERC7579Account, Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { FlashloanCallback } from "src/ColdStorage/FlashloanCallback.sol";
import { FlashloanLender } from "src/ColdStorage/FlashloanLender.sol";
import { ColdStorageHook } from "src/ColdStorage/ColdStorageHook.sol";
import { ColdStorageExecutor } from "src/ColdStorage/ColdStorageExecutor.sol";
import { OwnableValidator } from "src/OwnableValidator/OwnableValidator.sol";

import { ERC7579BootstrapConfig } from "@rhinestone/modulekit/src/external/ERC7579.sol";

import "src/ColdStorage/interfaces/Flashloan.sol";
import "erc7579/lib/ExecutionLib.sol";

contract ColdStorageTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ECDSA for bytes32;

    MockERC20 internal token;

    // main account and dependencies
    AccountInstance internal mainAccount;
    FlashloanCallback internal flashloanCallback;

    // ColdStorage Account and dependencies
    AccountInstance internal coldStorage;
    FlashloanLender internal flashloanLender;
    ColdStorageHook internal coldStorageHook;
    ColdStorageExecutor internal coldStorageExecutor;
    OwnableValidator internal ownableValidator;

    MockValidator internal mockValidator;

    Account owner;

    function setUp() public {
        init();

        flashloanLender = new FlashloanLender(address(coldStorage.aux.fallbackHandler));
        vm.label(address(flashloanLender), "flashloanLender");
        flashloanCallback = new FlashloanCallback(address(mainAccount.aux.fallbackHandler));
        vm.label(address(flashloanCallback), "flashloanCallback");
        ownableValidator = new OwnableValidator();
        vm.label(address(ownableValidator), "ownableValidator");
        mockValidator = new MockValidator();
        vm.label(address(mockValidator), "mockValidator");

        coldStorageHook = new ColdStorageHook();
        vm.label(address(coldStorageHook), "coldStorageHook");

        coldStorageExecutor = new ColdStorageExecutor();
        vm.label(address(coldStorageExecutor), "coldStorageExecutor");

        owner = makeAccount("owner");
        _setupMainAccount();
        _setUpColdstorage();

        deal(address(coldStorage.account), 100 ether);
        deal(address(mainAccount.account), 100 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), mainAccount.account, 100 ether);

        vm.warp(1_799_999);

        mainAccount.exec({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (address(coldStorage.account), 1 ether))
        });
    }

    function _setupMainAccount() public {
        ExtensibleFallbackHandler.Params[] memory params = new ExtensibleFallbackHandler.Params[](1);
        params[0] = ExtensibleFallbackHandler.Params({
            selector: IERC3156FlashBorrower.onFlashLoan.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Dynamic,
            handler: address(flashloanCallback)
        });

        ERC7579BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(ownableValidator), abi.encode(owner.addr));
        ERC7579BootstrapConfig[] memory executors =
            makeBootstrapConfig(address(flashloanCallback), abi.encode(""));
        ERC7579BootstrapConfig memory hook = _emptyConfig();
        ERC7579BootstrapConfig memory fallBack =
            _makeBootstrapConfig(address(auxiliary.fallbackHandler), abi.encode(params));
        mainAccount = makeAccountInstance("mainAccount", validators, executors, hook, fallBack);
    }

    function _setUpColdstorage() public {
        ExtensibleFallbackHandler.Params[] memory params = new ExtensibleFallbackHandler.Params[](6);
        params[0] = ExtensibleFallbackHandler.Params({
            selector: IERC3156FlashLender.maxFlashLoan.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Static,
            handler: address(flashloanLender)
        });
        params[1] = ExtensibleFallbackHandler.Params({
            selector: IERC3156FlashLender.flashFee.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Static,
            handler: address(flashloanLender)
        });
        params[2] = ExtensibleFallbackHandler.Params({
            selector: IERC3156FlashLender.flashLoan.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Dynamic,
            handler: address(flashloanLender)
        });
        params[3] = ExtensibleFallbackHandler.Params({
            selector: IERC6682.flashFeeToken.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Static,
            handler: address(flashloanLender)
        });
        params[4] = ExtensibleFallbackHandler.Params({
            selector: IERC6682.flashFee.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Static,
            handler: address(flashloanLender)
        });
        params[5] = ExtensibleFallbackHandler.Params({
            selector: IERC6682.availableForFlashLoan.selector,
            fallbackType: ExtensibleFallbackHandler.FallBackType.Static,
            handler: address(flashloanLender)
        });

        ERC7579BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(ownableValidator), abi.encode(address(mainAccount.account)));

        address[] memory addresses = new address[](2);
        bytes[] memory callData = new bytes[](2);

        addresses[0] = address(flashloanLender);
        addresses[1] = address(coldStorageExecutor);

        callData[0] = abi.encode("");
        callData[1] = abi.encodePacked(address(mainAccount.account));

        ERC7579BootstrapConfig[] memory executors = makeBootstrapConfig(addresses, callData);

        ERC7579BootstrapConfig memory hook = _makeBootstrapConfig(
            address(coldStorageHook), abi.encode(uint128(7 days), address(mainAccount.account))
        );
        ERC7579BootstrapConfig memory fallBack =
            _makeBootstrapConfig(address(auxiliary.fallbackHandler), abi.encode(params));

        coldStorage = makeAccountInstance("coldStorage", validators, executors, hook, fallBack);
    }

    function simulateDeposit() internal {
        vm.prank(mainAccount.account);
        token.transfer(coldStorage.account, 1 ether);
    }

    function signHash(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ECDSA.toEthSignedMessageHash(digest));
        return abi.encodePacked(r, s, v);
    }

    function _deploySubAccount() private {
        // todo: replace with modulekit function to deploy account
        // create and exec an empty user op to deploy the sub account
        UserOpData memory userOpData =
            coldStorage.getExecOps(address(0), 0, "", address(ownableValidator));

        bytes memory signature = signHash(owner.key, userOpData.userOpHash);
        signature = abi.encodePacked(address(ownableValidator), signature);
        userOpData.userOp.signature = signature;
        coldStorage.expect4337Revert();
        userOpData.execUserOps();
    }

    function _requestWithdraw(Execution memory exec, uint256 additionalDelay) internal {
        bytes memory subAccountCallData = ExecutionLib.encodeSingle(
            address(coldStorageHook),
            0,
            abi.encodeWithSelector(
                ColdStorageHook.requestTimelockedExecution.selector, exec, additionalDelay
            )
        );

        UserOpData memory userOpData = mainAccount.getExecOps({
            target: address(coldStorageExecutor),
            value: 0,
            callData: abi.encodeWithSelector(
                ColdStorageExecutor.executeOnSubAccount.selector,
                address(coldStorage.account),
                subAccountCallData
            ),
            txValidator: address(ownableValidator)
        });

        bytes memory signature = signHash(owner.key, userOpData.userOpHash);
        address recover =
            ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpData.userOpHash), signature);
        assertEq(recover, owner.addr);
        userOpData.userOp.signature = signature;
        userOpData.execUserOps();
    }

    function _execWithdraw(Execution memory exec) internal {
        bytes memory subAccountCallData =
            ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData);

        UserOpData memory userOpData = mainAccount.getExecOps({
            target: address(coldStorageExecutor),
            value: 0,
            callData: abi.encodeWithSelector(
                ColdStorageExecutor.executeOnSubAccount.selector,
                address(coldStorage.account),
                subAccountCallData
            ),
            txValidator: address(ownableValidator)
        });
        bytes memory signature = signHash(owner.key, userOpData.userOpHash);
        userOpData.userOp.signature = signature;
        userOpData.execUserOps();
    }

    function test_withdraw() public {
        uint256 prevBalance = token.balanceOf(address(mainAccount.account));
        uint256 amountToWithdraw = 100;

        _deploySubAccount();

        Execution memory action = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(
                MockERC20.transfer.selector, address(mainAccount.account), amountToWithdraw
            )
        });

        _requestWithdraw(action, 0);

        coldStorageHook.setWaitPeriod(7 days);

        vm.warp(block.timestamp + 8 days);
        _execWithdraw(action);

        uint256 newBalance = token.balanceOf(address(mainAccount.account));
        assertEq(newBalance, prevBalance + amountToWithdraw);
    }

    function test_setWaitPeriod() public {
        _deploySubAccount();

        uint256 newWaitPeriod = 2 days;

        Execution memory action = Execution({
            target: address(coldStorageHook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, (newWaitPeriod))
        });

        _requestWithdraw(action, 0);
        (bytes32 hash, bytes32 entry) =
            coldStorageHook.checkHash(address(mainAccount.account), action);

        vm.warp(block.timestamp + 8 days);
        _execWithdraw(action);

        Execution memory newAction = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(
                MockERC20.transfer.selector, address(mainAccount.account), 100
            )
        });

        _requestWithdraw(newAction, 0);

        vm.warp(block.timestamp + newWaitPeriod);
        _execWithdraw(newAction);

        uint256 updatedWaitPeriod = coldStorageHook.getLockTime(address(coldStorage.account));
        assertEq(updatedWaitPeriod, uint128(newWaitPeriod));
    }

    function test_withdraw__With__NativeToken() public {
        address target = address(mainAccount.account);
        uint256 prevBalance = target.balance;
        uint256 amountToWithdraw = 1 ether;

        vm.deal(address(coldStorage.account), 10 ether);
        _deploySubAccount();

        Execution memory action =
            Execution({ target: target, value: amountToWithdraw, callData: "" });

        _requestWithdraw(action, 0);

        vm.warp(block.timestamp + 8 days);
        _execWithdraw(action);

        uint256 newBalance = target.balance;
        assertTrue(newBalance > prevBalance);
    }
}
