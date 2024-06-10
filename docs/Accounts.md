# Accounts

ModuleKit currently supports the following accounts:

- [ERC-7579 Reference Implementation](https://github.com/erc7579/erc7579-implementation)
- [Safe](https://github.com/safe-global/safe-smart-account) via [Safe7579](https://github.com/rhinestonewtf/safe7579)
- [Kernel](https://github.com/zerodevapp/kernel)

To use different accounts, a developer can simply change the account on which their tests are run (the default is the ERC-7579 Reference Implementation). To do this, run:

```bash
ACCOUNT_TYPE=... pnpm test
```

where the options are:

- `DEFAULT`: The ERC-7579 Reference Implementation (note: this is equivalent to emitting the `ACCOUNT_TYPE` environment variable)
- `SAFE`: The Safe account
- `KERNEL`: The Kernel account

## Differences

While ModuleKit aims to abstract as much about the accounts away from the developer as possible, there are some differences between the accounts that are important to note. Further, the ModuleKit uses these accounts in a way that might not allow the developer to make use of all features that an account has or might be using a flow different from what will be used in production. To ensure that you benefit from the abstraction of these differences, use the ModuleKit provided helper functions, through the `ModuleKitHelpers` library, rather than creating these integration flows from scratch. This document is aimed at giving an overview of these differences.

### ERC-7579 Reference Implementation

The ERC-7579 Reference Implementation is a simple implementation of the ERC-7579 standard. It is fairly minimal and unopinionated and hence the ModuleKit uses it as the default account. It also does not provide any further features beyond what is required by the standard, so the ModuleKit uses all of its' features.

### Safe

The Safe7579 is an adapter to Safe accounts that allows them to become compatible with the standard. Concretely, this means that it will be installed as a fallback handler on the Safe. The Safe7579 is also fairly minimal, but there are some key differences to the ERC-7579 Reference Implementation:

- The Safe7579 does not have access to the `msg.value` sent to the account.
- The Safe7579 stores the account config (ie installed modules) in the adapter itself rather than in the account.
- The Safe7579 has both global hooks that get called on every execution and signature specific hooks that get called based on the function signature of the target.
- The Safe7579 should be used with its' launchpad to bootstrap the Safe. This means that the first UserOperation will be sent to the `setUp` function, however this is abstracted away from the developer in the ModuleKit.

### Kernel

The Kernel is a more complex account that has a lot of unique features and design choices. The ModuleKit does not use all of these features and instead uses only those features that are shared by other accounts. The Kernel has the following differences:

- It supports policies and signers, which are new module types that other accounts do not (yet) support.
- Hooks are related to both validators and executors where each of these has an associated hook. The ModuleKit uses a multiplexer as the hook for each of these so that global hooks can be emulated on the Kernel. Note, that this might differ from a production setup.
- Validators need to be assigned function selectors that they are allowed to validate. The ModuleKit abstracts this away from the developer and allows any validator to sign any UserOperation with any calldata.
- Kernel requires non-root validators with hooks to use `executeUserOp`. Hence, almost all transactions will use this function rather than the direct entrypoint into the account.
