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
- [x] RegistryHook
  - [x] Unit
  - [x] Integration
- [x] ScheduledOrders
  - [x] Unit
  - [x] Integration
- [x] ScheduledTransactions
  - [x] Unit
  - [x] Integration
- [x] SocialRecovery
  - [x] Unit
  - [x] Integration

Open questions

- coldstorage blocks flashloan
- coldstorage blocks module installation
- if module is installed using execute, then call to account install module then hook destruct does not detect this
- stateless validation
- hook changes
- coldstorage: is it acutally necessary to check anything in postcheck?
- ownable executor should allow batch calls?
- get owners/guardians: how to return all?

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
