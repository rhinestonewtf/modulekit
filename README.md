# ModuleKit

The ModuleKit is a development kit for building and testing smart account modules. ModuleKit allows you to:

-   **Easily build smart account modules** with interfaces for:
    -   Validators
    -   Executors
    -   Recovery modules
    -   Hooks
-   **Unit test** your modules using a dedicated helper library
-   **Integration test** your modules using modular ERC-4337 accounts and a helper library that abstracts away almost all the complexity

## Installation

### With Foundry

```bash
forge install rhinestonewtf/modulekit
```

### Using our template

```bash
git clone https://github.com/rhinestonewtf/module-template.git
cd module-template
forge install
```

## Helper utilities

### Building modules

#### Interfaces

-   `IExecutorBase`: Interface for Executors to inherit from.
-   `BaseValidator`: Interface for Validator Modules to inherit from.
-   `IRecoveryModule`: Interface for Recovery Modules to inherit from.

#### Templates

-   [Validator](https://github.com/rhinestonewtf/module-template/blob/main/src/validators/ValidatorTemplate.sol): Template implementation for Validators.

### Testing modules

#### RhinestoneModuleKitLib

-   `function exec4337(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData) internal returns (bool, bytes memory)`: Executes a UserOperation from the account using a `target`, a `value` and an already-encoded `callData`. Can only use use `CALL` from the account and calculates a default signature.
-   `function exec4337(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData, uint8 operation, bytes memory signature) internal returns (bool, bytes memory)`: Executes a UserOperation from the account using a `target`, a `value` and an already-encoded `callData`. Can use either `CALL` or `DELEGATECALL` from the account and uses the provided `signature`.
-   `function addValidator(RhinestoneAccount memory instance, address validator) internal returns (bool)`: Adds a validator to the account.
-   `function addRecovery(RhinestoneAccount memory instance, address validator, address recovery) internal returns (bool)`: Adds a recovery module to the account.
-   `function addExecutor(RhinestoneAccount memory instance, address executor) internal returns (bool)`: Adds a executor to the account.
-   `function removeExecutor(RhinestoneAccount memory instance, address executor) internal returns (bool)`: Removes a executor from the account.
-   `function getUserOpHash(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData, uint8 operation) internal returns (bytes32)`: Calculates the hash of a UserOperation in order to be signed for a custom signature.


## Credits
- [Safe{Core} Protocol](https://github.com/safe-global/safe-core-protocol/): ExecutorManager.sol is heavily insprired by Safe's SafeProtocolManager
