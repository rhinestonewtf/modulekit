<img src=".github/logo.png" alt="rhinestone logo" align="right" width="120" height="120" style="border-radius:20px"/>

## rhinestone ModuleKit

**A development kit for building and testing smart account modules.**

ModuleKit allows you to:

- **Easily build smart account modules** with interfaces for:
  - Validators
  - Executors
  - Recovery modules
  - Hooks
- **Unit test** your modules using a dedicated helper library
- **Integration test** your modules using modular ERC-4337 accounts and a helper library that abstracts away almost all the complexity

**Need help getting started with ModuleKit? Check out the [docs][rs-docs]!**

## Installation with Foundry

```sh
forge install rhinestonewtf/modulekit
```

## Features

- [ ] ERC-4337 integration tests
  - [x] On-chain integration test (EntryPoint -> Account)
  - [ ] Off-chain integration test (Bundler simulation and rule validation)
- [ ] Module unit testing library
- [ ] Different Module types
  - [x] Validators
  - [x] Executors
  - [x] Recovery modules
  - [ ] Hooks
- [ ] Different modular accounts
  - [x] Safe
  - [ ] Kernel
  - [ ] Biconomy
  - [ ] ERC-6900 reference implementation

## Helper utilities

### Building modules

#### Interfaces

- `IPluginBase`: Interface for Plugins to inherit from.
- `BaseValidator`: Interface for Validator Modules to inherit from.
- `IRecoveryModule`: Interface for Recovery Modules to inherit from.

### Testing modules

#### RhinestoneModuleKitLib

- `function exec4337(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData) internal returns (bool, bytes memory)`: Executes a UserOperation from the account using a `target`, a `value` and an already-encoded `callData`. Can only use use `CALL` from the account and calculates a default signature.
- `function exec4337(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData, uint8 operation, bytes memory signature) internal returns (bool, bytes memory)`: Executes a UserOperation from the account using a `target`, a `value` and an already-encoded `callData`. Can use either `CALL` or `DELEGATECALL` from the account and uses the provided `signature`.
- `function addValidator(RhinestoneAccount memory instance, address validator) internal returns (bool)`: Adds a validator to the account.
- `function addRecovery(RhinestoneAccount memory instance, address validator, address recovery) internal returns (bool)`: Adds a recovery module to the account.
- `function addPlugin(RhinestoneAccount memory instance, address plugin) internal returns (bool)`: Adds a plugin to the account.
- `function removePlugin(RhinestoneAccount memory instance, address plugin) internal returns (bool)`: Removes a plugin from the account.
- `function getUserOpHash(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData, uint8 operation) internal returns (bytes32)`: Calculates the hash of a UserOperation in order to be signed for a custom signature.

## Contributing

See our [contributing guidelines](./CONTRIBUTING.md).

## Getting Help

First, see if the answer to your question can be found in the [docs][rs-docs].

If the answer is not there:

- Open a [discussion](https://github.com/rhinestonewtf/modulekit/discussions/new) with your question, or
- Open an issue with [the bug](https://github.com//rhinestonewtf/modulekit/issues/new)

[rs-docs]: https://docs.rhinestone.wtf
