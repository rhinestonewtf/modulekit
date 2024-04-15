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
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] ColdStorageHook
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] OwnableExecutor
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] Flashloan
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] DeadmanSwitch
  - [x] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] HookMultiPlexer
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] MFA
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] OwnableValidator
  - [x] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] RegistryHook
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] ScheduledOrders
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] ScheduledTransactions
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz
- [ ] SocialRecovery
  - [ ] Unit
  - [ ] Integration
  - [ ] Fuzz

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
