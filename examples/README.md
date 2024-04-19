## ModuleKit Examples

**Example modules built using the ModuleKit**

Modules:

- AutoSavings
- AutoSend
- ColdStorage
- Deadman Switch
- Dollar Cost Averaging
- ERC1271 PreHash Validator
- Multi Factor Authentication
- ECDSA Validator (OwnableValidator)
- Scheduled Transactions
- Automated Token Revocation
- Webauthn Validator

Tested:

- [x] AutoSavings
  - [x] Unit
  - [x] Integration
- [x] ColdStorageHook
  - [x] Unit
  - [x] Integration
- [ ] Flashloan
  - [ ] Unit
  - [ ] Integration
- [x] DeadmanSwitch
  - [x] Unit
  - [x] Integration
- [ ] HookMultiPlexer
  - [ ] Unit
  - [ ] Integration
- [ ] MFA
  - [ ] Unit
  - [ ] Integration
- [x] OwnableExecutor
  - [x] Unit
  - [x] Integration
- [x] OwnableValidator
  - [x] Unit
  - [x] Integration
- [ ] RegistryHook
  - [x] Unit
  - [ ] Integration
- [ ] ScheduledOrders
  - [x] Unit
  - [ ] Integration
- [ ] ScheduledTransactions
  - [x] Unit
  - [ ] Integration
- [ ] SocialRecovery
  - [x] Unit
  - [ ] Integration

## Usage as part of ModuleKit

### Install dependencies

```shell
pnpm install
```

### Testing modules

```shell
pnpm test -r
```

## Learn more

For more information, check out the [ModuleKit documentation](https://docs.rhinestone.wtf/modulekit).
