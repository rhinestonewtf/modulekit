# ModuleKit

**A development kit for building and testing smart account modules.**

ModuleKit allows you to:

- **Easily build smart account modules** with interfaces for:
  - Validators
  - Executors
  - Hooks
- **Unit test** your modules using a dedicated helper library
- **Integration test** your modules using different modular ERC-4337 accounts and a helper library that abstracts away the complexity

In-depth documentation is available at [docs.rhinestone.wtf](https://docs.rhinestone.wtf/modulekit/).

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
- [x] Deployment helper using Module Registry
- [ ] Gas calculation helper

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.

For guidance on how to create PRs, see the [CONTRIBUTING](./CONTRIBUTING.md) guide.

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
