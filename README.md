<img src=".github/logo.png" alt="rhinestone logo" align="right" width="120" height="120" style="border-radius:20px"/>

## rhinestone ModuleKit

**A development kit for building and testing smart account modules.**

ModuleKit allows you to:

- **Easily build smart account modules** with interfaces for:
  - Validators
  - Executors
  - Recovery modules
  - Hooks
- **Unit test** your modules using a helper library
- **Integration test** your modules using modular ERC-4337 accounts and a helper library

**Need help getting started with ModuleKit? Check out the [docs][rs-docs]!**

## Installation with Foundry

```sh
forge install rhinestonewtf/modulekit
```

## Features

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

- `function warp(uint x) public` Sets the block timestamp to `x`.

- `function difficulty(uint x) public` Sets the block difficulty to `x`.

- `function roll(uint x) public` Sets the block number to `x`.

### Testing modules

- `function warp(uint x) public` Sets the block timestamp to `x`.

- `function difficulty(uint x) public` Sets the block difficulty to `x`.

- `function roll(uint x) public` Sets the block number to `x`.

## Contributing

See our [contributing guidelines](./CONTRIBUTING.md).

## Getting Help

First, see if the answer to your question can be found in the [docs][rs-docs].

If the answer is not there:

- Open a [discussion](https://github.com/rhinestonewtf/module-kit/discussions/new) with your question, or
- Open an issue with [the bug](https://github.com//rhinestonewtf/module-kit/issues/new)

[rs-docs]: https://docs.rhinestone.wtf
