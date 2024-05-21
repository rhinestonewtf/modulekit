# ModuleKit

**A development kit for building and testing smart account modules**

ModuleKit allows you to:

- **Easily build smart account modules** with interfaces for:
  - Validators
  - Executors
  - Hooks
- **Unit test** your modules using a dedicated helper library
- **Integration test** your modules using different modular ERC-4337 accounts and a helper library that abstracts away the complexity

In-depth documentation is available at [docs.rhinestone.wtf](https://docs.rhinestone.wtf/modulekit/).

> The ModuleKit is in active development and is subject to breaking changes. If you spot a bug, please take out an issue and we will fix it as soon as we can.

## Using the ModuleKit

### Installation

#### Using our template

Use the [module-template](https://github.com/rhinestonewtf/module-template) to create a new repo and install the dependencies:

```bash
pnpm install
```

#### Using git submodules

```bash
forge install rhinestonewtf/modulekit
cd lib/modulekit
pnpm install
```

#### Using a package manager

```bash
pnpm install @rhinestone/modulekit --node-linker=hoisted
cp node_modules/@rhinestone/modulekit/remappings.txt remappings.txt
```

### Updating

To update the ModuleKit, run:

```bash
forge update rhinestonewtf/modulekit
```

or

```bash
pnpm update @rhinestone/modulekit
```

### Usage

To learn more about using ModuleKit, visit the [modulekit section](https://docs.rhinestone.wtf/modulekit) of the docs. To get a better understanding of Modules generally, visit the [modules section](https://docs.rhinestone.wtf/overview/modules) and for hands-on tutorials on the entire lifecycle of modules, visit the [tutorials section](https://docs.rhinestone.wtf/modulekit/build-multi-owner-validator).

## Features

- [x] ERC-4337 integration tests
  - [x] On-chain integration test (EntryPoint -> Account)
  - [x] Off-chain integration test (Bundler simulation and spec validation)
- [ ] Unit testing library
- [x] Different Module types
  - [x] Validators
  - [x] Executors
  - [x] Hooks
  - [x] Fallbacks
- [x] Different Modular Accounts
  - [x] ERC-7579
  - [x] Safe
  - [ ] Biconomy
  - [ ] Kernel
- [x] Deployment helper using Module Registry
- [x] Gas calculation helper

## Examples

For module examples, check out our [core modules](https://github.com/rhinestonewtf/core-modules/) or our [experimental modules](https://github.com/rhinestonewtf/experimental-modules/) and for module inspiration see our [module idea list](https://rhinestone.notion.site/Module-ideas-for-product-inspo-338100a2c99540f490472b8aa839da11). For general examples, check out the [awesome modular accounts repo](https://github.com/rhinestonewtf/awesome-modular-accounts).

### Using this repo

To install dependencies, run:

```bash
pnpm install
```

To build the project, run:

```bash
pnpm build
```

To run tests, run:

```bash
pnpm test
```

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.
