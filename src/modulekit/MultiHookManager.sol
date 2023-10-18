// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IExecutor.sol";
import "./IHook.sol";

contract MultiHookManager is IHook {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address account => EnumerableSet.AddressSet) _subHooks;

    event SubHookAdded(address account, address hook);

    function addSubHook(address hook) external {
        _subHooks[msg.sender].add(hook);
        emit SubHookAdded(msg.sender, hook);
    }

    function preCheck(
        address account,
        ExecutorTransaction calldata transaction,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    {
        EnumerableSet.AddressSet storage subHooks = _subHooks[account];
        uint256 subHookLength = subHooks.length();
        bytes[] memory preCheckDatas = new bytes[](subHookLength);

        for (uint256 i; i < subHookLength; i++) {
            preCheckDatas[i] =
                IHook(subHooks.at(i)).preCheck(account, transaction, executionType, executionMeta);
        }
        preCheckData = abi.encode(preCheckDatas);
    }

    function preCheckRootAccess(
        address account,
        ExecutorTransaction calldata rootAccess,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    { }

    function postCheck(
        address account,
        bool success,
        bytes calldata preCheckData
    )
        external
        override
    {
        EnumerableSet.AddressSet storage subHooks = _subHooks[account];
        bytes[] memory preCheckDatas = abi.decode(preCheckData, (bytes[]));
        uint256 subHookLength = subHooks.length();
        if (subHookLength != preCheckDatas.length) revert();

        for (uint256 i; i < subHookLength; i++) {
            IHook(subHooks.at(i)).postCheck(account, success, preCheckDatas[i]);
        }
    }
}
