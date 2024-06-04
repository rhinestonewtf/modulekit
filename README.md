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
pnpm install @rhinestone/modulekit --shamefully-hoist
cp node_modules/@rhinestone/modulekit/remappings.txt remappings.txt
```

### Usage

The ModuleKit can be used to **build**, **test** and **deploy** smart account modules. The full documentation is available at [docs.rhinestone.wtf](https://docs.rhinestone.wtf/modulekit/), but the following aims to provide a quick overview.

### Building modules

Import Module bases from `modulekit/Modules.sol`. The core bases include:

- `ERC7579ValidatorBase`: A base for building validators
- `ERC7579ExecutorBase`: A base for building executors
- `ERC7579HookBase`: A base for building hooks
- `ERC7579HookDestruct`: A base for building hooks with destructured calldata (e.g. `onExecute` or `onInstallModule`)
- `ERC7579FallbackBase`: A base for building fallbacks

We also provide more advanced bases like:

- `SchedulingBase`: A base for building schedule-based executors
- `ERC7484RegistryAdapter`: A base for querying the Module Registry

### Testing modules

The ModuleKit provides an integration test suite for testing your modules across different modular accounts. To use the test suite, inherit from `RhinestoneModuleKit` and create an account instance using `makeAccountInstance(accountName)`. To learn more about using this instance, visit the documentation for our [integration test suite](https://docs.rhinestone.wtf/modulekit/test/integration).

You can then run the tests using the following commands:

```bash
forge test
```

Using a different account type (one of `SAFE` and `KERNEL`):

```bash
ACCOUNT_TYPE=SAFE forge test
```

To validate the ERC-4337 rules:

```bash
SIMULATE=true forge test
```

To calculate gas consumption of modules using `instance.log4337Gas("identifier")`:

```bash
GAS=true forge test
```

### Deploying modules

To deploy modules using the [Module Registry](https://github.com/rhinestonewtf/registry/), you can use the `RegistryDeployer` in a foundry script. You can then deploy your module using the following command:

```solidity
address module = deployModule({
    code: bytecode,
    deployParams: deployParams,
    salt: bytes32(0),
    data: additionalData
});
```

## Module Examples

For module examples, check out our [core modules](https://github.com/rhinestonewtf/core-modules/) or our [experimental modules](https://github.com/rhinestonewtf/experimental-modules/) and for module inspiration see our [module idea list](https://rhinestone.notion.site/Module-ideas-for-product-inspo-338100a2c99540f490472b8aa839da11). For general examples, check out the [awesome modular accounts repo](https://github.com/rhinestonewtf/awesome-modular-accounts).

## Using this repo

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

To run the linter, run:

```bash
pnpm lint:sol
```

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.
