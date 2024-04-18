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

- [ ] AutoSavings
  - [x] Unit
  - [ ] Integration
- [ ] ColdStorageHook
  - [ ] Unit
  - [ ] Integration
- [ ] Flashloan
  - [ ] Unit
  - [ ] Integration
- [ ] DeadmanSwitch
  - [x] Unit
  - [ ] Integration
- [ ] HookMultiPlexer
  - [ ] Unit
  - [ ] Integration
- [ ] MFA
  - [ ] Unit
  - [ ] Integration
- [ ] OwnableExecutor
  - [x] Unit
  - [ ] Integration
- [ ] OwnableValidator
  - [x] Unit
  - [ ] Integration
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
