// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { ExecutorManager,ExecutorTransaction, ExecutorAction } from "../../src/core/ExecutorManager.sol";
import { MockRegistry, IERC7484Registry } from "../../src/test/mocks/MockRegistry.sol";

contract FalseRegistry is IERC7484Registry {
    function check(
        address executor,
        address trustedAuthority
    )
        external
        view
        override
        returns (uint256 listedAt)
    {
        assembly {
            revert(0, 0)
        }
    }

    function checkN(
        address module,
        address[] memory attesters,
        uint256 threshold
    )
        external
        view
        override
        returns (uint256[] memory)
    {
        assembly {
            revert(0, 0)
        }
    }
}

contract ExecutorManagerInstance is ExecutorManager {
    constructor(IERC7484Registry registry) ExecutorManager(registry) { }

    function _execTransationOnSmartAccount(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        override
        returns (bool, bytes memory)
    {
        return to.call{value:value}(data);
    }
}

contract ExecutorManagerTest is Test {
    MockRegistry registry;
    ExecutorManagerInstance executorManager;

    function setUp() public {
        registry = new MockRegistry();
        executorManager = new ExecutorManagerInstance(registry);
    }

    function testSetTrustedAttester() public {
        address attester = makeAddr("attester");
        address account = makeAddr("account");

        vm.startPrank(account);
        vm.expectEmit(true, true, true, true);
        emit TrustedAttesterSet(account, attester);
        executorManager.setTrustedAttester(attester);
        vm.stopPrank();
    }

    function testEnableExecutor() public {
        address executor = makeAddr("executor");
        address account = makeAddr("account");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();
        assertTrue(executorManager.isExecutorEnabled(account, executor));
    }

    function testEnableExecutor__RevertWhen__NoZeroOrSentinelExecutor__AddressZero() public {
        address account = makeAddr("account");
        address executor = address(0);

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(ExecutorManager.InvalidExecutorAddress.selector, executor)
        );
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();
    }

    function testEnableExecutor__RevertWhen__NoZeroOrSentinelExecutor__AddressSentinel() public {
        address account = makeAddr("account");
        address executor = address(0x1);

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(ExecutorManager.InvalidExecutorAddress.selector, executor)
        );
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();
    }

    function testEnableExecutor__RevertWhen__InsecureModule() public {
        IERC7484Registry falseRegistry = new FalseRegistry();
        ExecutorManagerInstance insecureRegistryExecutorManager =
            new ExecutorManagerInstance(falseRegistry);

        address account = makeAddr("account");
        address executor = makeAddr("executor");

        vm.startPrank(account);
        vm.expectRevert();
        insecureRegistryExecutorManager.enableExecutor(executor, false);
        vm.stopPrank();
    }

    function testEnableExecutor__RevertWhen__AlreadyEnabled() public {
        address executor = makeAddr("executor");
        address account = makeAddr("account");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.ExecutorAlreadyEnabled.selector, account, executor
            )
        );
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();
    }

    function testDisableExecutor() public {
        address executor = makeAddr("executor");
        address account = makeAddr("account");
        address prevExecutor = address(0x1);

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();
        assertTrue(executorManager.isExecutorEnabled(account, executor));

        vm.startPrank(account);
        executorManager.disableExecutor(prevExecutor, executor);
        vm.stopPrank();
        assertFalse(executorManager.isExecutorEnabled(account, executor));
    }

    function testDisableExecutor__RevertWhen__NoZeroOrSentinelExecutor__AddressZero() public {
        address account = makeAddr("account");
        address executor = address(0);
        address prevExecutor = address(0x1);

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(ExecutorManager.InvalidExecutorAddress.selector, executor)
        );
        executorManager.disableExecutor(prevExecutor, executor);
        vm.stopPrank();
    }

    function testDisableExecutor__RevertWhen__NoZeroOrSentinelExecutor__AddressSentinel() public {
        address account = makeAddr("account");
        address executor = address(0x1);
        address prevExecutor = address(0x1);

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(ExecutorManager.InvalidExecutorAddress.selector, executor)
        );
        executorManager.disableExecutor(prevExecutor, executor);
        vm.stopPrank();
    }

    function testDisableExecutor__RevertWhen__InvalidPrevExecutorAddress() public {
        address account = makeAddr("account");
        address executor = makeAddr("executor");
        address prevExecutor = makeAddr("prevExecutor");

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.InvalidPrevExecutorAddress.selector, prevExecutor
            )
        );
        executorManager.disableExecutor(prevExecutor, executor);
        vm.stopPrank();
    }

    function testExecuteTransaction() public {
        address account = makeAddr("account");
        address executor = makeAddr("executor");
        address target = makeAddr("target");

        vm.deal(address(executorManager), 10 wei);

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();

        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = ExecutorAction({
            to: payable(target),
            value: 1 wei,
            data: ""
        });

        bytes32 metadataHash = keccak256(abi.encodePacked("fail()"));

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: actions,
            nonce: 0,
            metadataHash:metadataHash
        });

        vm.startPrank(executor);
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testExecuteTransaction__RevertWhen__ExecutorNotEnabled() public {
         address account = makeAddr("account");
        address executor = makeAddr("executor");

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: new ExecutorAction[](0),
            nonce: 0,
            metadataHash: ""
        });

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.ExecutorNotEnabled.selector, executor
            )
        );
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testExecuteTransaction__RevertWhen__InsecureModule() public {
        IERC7484Registry falseRegistry = new FalseRegistry();
            
         address account = makeAddr("account");
        address executor = makeAddr("executor");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();

        vm.etch(address(registry), address(falseRegistry).code);

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: new ExecutorAction[](0),
            nonce: 0,
            metadataHash: ""
        });

        vm.startPrank(executor);
        vm.expectRevert(
        );
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testExecuteTransaction__RevertWhen__CallingSelf() public {
         address account = makeAddr("account");
        address executor = makeAddr("executor");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();

        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = ExecutorAction({
            to: payable(address(executorManager)),
            value: 0,
            data: ""
        });

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: actions,
            nonce: 0,
            metadataHash: ""
        });

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.InvalidToFieldInSafeProtocolAction.selector, account, bytes32(0), 0
            )
        );
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testExecuteTransaction__RevertWhen__CallingAccount() public {
         address account = makeAddr("account");
        address executor = makeAddr("executor");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();

        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = ExecutorAction({
            to: payable(account),
            value: 0,
            data: ""
        });

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: actions,
            nonce: 0,
            metadataHash: ""
        });

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.InvalidToFieldInSafeProtocolAction.selector, account, bytes32(0), 0
            )
        );
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testExecuteTransaction__RevertWhen__ActionFails() public {
         address account = makeAddr("account");
        address executor = makeAddr("executor");
        address target = makeAddr("target");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        vm.stopPrank();

        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = ExecutorAction({
            to: payable(target),
            value: 1 wei,
            data: ""
        });

        bytes32 metadataHash = keccak256(abi.encodePacked("fail()"));

        ExecutorTransaction memory transaction = ExecutorTransaction({
            actions: actions,
            nonce: 0,
            metadataHash:metadataHash
        });

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.ActionExecutionFailed.selector, account, metadataHash, 0
            )
        );
        executorManager.executeTransaction(account, transaction);
        vm.stopPrank();
    }

    function testGetExecutorsPaginated() public {
        address account = makeAddr("account");
        address executor = makeAddr("executor");
        address executor2 = makeAddr("executor2");
        address executor3 = makeAddr("executor3");

        vm.startPrank(account);
        executorManager.enableExecutor(executor, false);
        executorManager.enableExecutor(executor2, false);
        executorManager.enableExecutor(executor3, false);
        vm.stopPrank();

        vm.startPrank(account);
        (address[] memory array, address next) = executorManager.getExecutorsPaginated(address(0x1), 3, account);
        vm.stopPrank();

        assertTrue(array.length == 3);
        assertTrue(array[0] == executor3);
        assertTrue(array[1] == executor2);
        assertTrue(array[2] == executor);
        assertTrue(next == address(0x1));
    }

    function testGetExecutorsPaginated__RevertWhen__ZeroPageSize() public {
        address account = makeAddr("account");
        address start = makeAddr("start");

        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.ZeroPageSizeNotAllowed.selector
            )
        );
        executorManager.getExecutorsPaginated(start, 0, account);
     }

     function testGetExecutorsPaginated__RevertWhen__InvalidStart() public {
        address account = makeAddr("account");
        address start = makeAddr("start");
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutorManager.InvalidExecutorAddress.selector, start
            )
        );
        executorManager.getExecutorsPaginated(start, 1, account);
     }

         event TrustedAttesterSet(address indexed account, address indexed attester);

}
