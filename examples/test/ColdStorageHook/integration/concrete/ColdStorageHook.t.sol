// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { ColdStorageHook, Execution } from "src/ColdStorageHook/ColdStorageHook.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_HOOK, MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract ColdStorageHookIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ColdStorageHook internal hook;
    MockERC20 internal token;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _owner;
    uint128 _waitPeriod;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();
        hook = new ColdStorageHook();

        _owner = makeAddr("owner");
        _waitPeriod = uint128(100);

        token = new MockERC20("USDC", "USDC", 18);
        vm.label(address(token), "USDC");
        token.mint(address(instance.account), 1_000_000);

        vm.etch(_owner, hex"00");

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: _owner, data: "" });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encodePacked(_waitPeriod, _owner)
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function _cueAndWaitForExecution(Execution memory _exec, uint256 additionalWait) internal {
        vm.prank(_owner);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(
                address(hook),
                0,
                abi.encodeWithSelector(
                    ColdStorageHook.requestTimelockedExecution.selector, _exec, additionalWait
                )
            )
        );

        vm.warp(block.timestamp + _waitPeriod + additionalWait);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetsOwnerAndWaitPeriod() public {
        // it should set the owner and waitperiod
        bool isInitialized = hook.isInitialized(address(instance.account));
        assertTrue(isInitialized);

        (uint128 waitPeriod, address owner) = hook.vaultConfig(address(instance.account));
        assertEq(waitPeriod, _waitPeriod);
        assertEq(owner, _owner);
    }

    function test_OnUninstallRemovesOwnerAndWaitPeriod() public {
        // it should remove the owner and waitperiod
        Execution memory exec = Execution({
            target: address(instance.account),
            value: 0,
            callData: abi.encodeWithSelector(
                IERC7579Account.uninstallModule.selector, MODULE_TYPE_HOOK, address(hook), ""
            )
        });

        _cueAndWaitForExecution(exec, 0);

        vm.prank(_owner);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData)
        );

        bool isInitialized = hook.isInitialized(address(instance.account));
        assertFalse(isInitialized);

        (uint128 waitPeriod, address owner) = hook.vaultConfig(address(instance.account));
        assertEq(waitPeriod, 0);
        assertEq(owner, address(0));
    }

    function test_SetWaitPeriod() public {
        // it should set the wait period
        uint128 newWaitPeriod = uint128(200);

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, newWaitPeriod)
        });

        _cueAndWaitForExecution(exec, 0);

        vm.prank(_owner);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData)
        );

        (uint128 waitPeriod,) = hook.vaultConfig(address(instance.account));
        assertEq(waitPeriod, newWaitPeriod);
    }

    function test_TransferNativeTokens() public {
        uint256 amount = 100;
        uint256 prevBalance = _owner.balance;

        Execution memory exec = Execution({ target: _owner, value: amount, callData: "" });

        _cueAndWaitForExecution(exec, 0);

        vm.prank(_owner);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData)
        );

        uint256 newBalance = _owner.balance;
        assertEq(newBalance, prevBalance + amount);
    }

    function test_TransferERC20Tokens() public {
        uint256 amount = 100;
        uint256 prevBalance = token.balanceOf(_owner);

        Execution memory exec = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, _owner, amount)
        });

        _cueAndWaitForExecution(exec, 0);

        vm.prank(_owner);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData)
        );

        uint256 newBalance = token.balanceOf(_owner);
        assertEq(newBalance, prevBalance + amount);
    }

    function test_FlashloanERC20Tokens() public {
        // install flashloan on owner

        // owner calls into account to flashloan

        // owner calls onFlashLoan on owner

        // Execution memory exec = Execution({
        //     target: address(token),
        //     value: 0,
        //     callData: abi.encodeWithSelector(IERC20.transfer.selector, _owner, amount)
        // });
        // vm.prank(_owner);
        // IERC7579Account(instance.account).executeFromExecutor(
        //     ModeLib.encodeSimpleSingle(),
        //     ExecutionLib.encodeSingle(exec.target, exec.value, exec.callData)
        // );
        //
        // uint256 newBalance = token.balanceOf(_owner);
        // assertEq(newBalance, prevBalance + amount);
    }
}
