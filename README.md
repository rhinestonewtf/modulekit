# ModuleKit

The ModuleKit is a development kit for building and testing smart account modules. ModuleKit allows you to:

- **Easily build smart account modules** with interfaces for:
  - Validators
  - Executors
  - Recovery modules
  - Hooks
- **Unit test** your modules using a dedicated helper library
- **Integration test** your modules using modular ERC-4337 accounts and a helper library that abstracts away almost all the complexity

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

## Updating

To update the ModuleKit, run:

```bash
forge update rhinestonewtf/modulekit
```

## Features

- [ ] ERC-4337 integration tests
  - [x] On-chain integration test (EntryPoint -> Account)
  - [ ] Off-chain integration test (Bundler simulation and spec validation)
- [ ] Unit testing library
- [ ] Different Module types
  - [x] Validators
  - [x] Executors
  - [ ] Hooks
- [ ] Different modular accounts
  - [x] Safe
  - [x] Biconomy
  - [ ] Kernel
  - [ ] ERC-6900 reference implementation
- [x] Deployment through Module Registry
- [ ] Gas calculation helper

## Helper utilities

### Building modules

#### Interfaces

- `ValidatorBase`: Interface for Validators to inherit from.
- `ExecutorBase`: Interface for Executors to inherit from.

#### Templates

- [Validator](https://github.com/rhinestonewtf/module-template/blob/main/src/validators/ValidatorTemplate.sol): Template implementation for Validators.
- [Executor](https://github.com/rhinestonewtf/module-template/blob/main/src/executors/ExecutorTemplate.sol): Template implementation for Executors.

### Testing modules

New docs coming soon

## Contribute

For feature or change requests, feel free to open a PR or get in touch with us.

## Credits

- [Safe{Core} Protocol](https://github.com/safe-global/safe-core-protocol/): ExecutorManager.sol is heavily insprired by Safe's SafeProtocolManager but is compatible across all supported accounts

## Authors ✨

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://twitter.com/zeroknotsETH/"><img src="https://pbs.twimg.com/profile_images/1639062011387715590/bNmZ5Gpf_400x400.jpg" width="100px;" alt=""/><br /><sub><b>zeroknots</b></sub></a><br /><a href="https://github.com/rhinestonewtf/registry/commits?author=zeroknots" title="Code">💻</a></td>
    <td align="center"><a href="https://twitter.com/abstractooor"><img src="https://avatars.githubusercontent.com/u/26718079" width="100px;" alt=""/><br /><sub><b>Konrad</b></sub></a><br /><a href="https://github.com/rhinestonewtf/registry/commits?author=kopy-kat" title="Code">💻</a> </td>
    
  </tr>
</table>
