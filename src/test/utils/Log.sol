// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library ModuleKitLogs {
    event ModuleKit_NewAccount(address account, string accountType);
    event ModuleKit_Exec4337(address account, address sender);

    event ModuleKit_AddExecutor(address account, address executor);
    event ModuleKit_RemoveExecutor(address account, address executor);

    event ModuleKit_AddValidator(address account, address validator);
    event ModuleKit_RemoveValidator(address account, address validator);

    event ModuleKit_SetFallback(address account, bytes4 functionSig, address handler);

    event ModuleKit_SetCondition(address account, address executor);
}
