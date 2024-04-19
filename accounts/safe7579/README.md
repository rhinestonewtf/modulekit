## How Safe7579 works

Safe7579 provides full `ERC4337` and `ERC7579` compliance to Safe accounts by serving as the Safe's `FallbackHandler` and an enabled module. This setup allows Safe accounts to utilize all `ERC7579` modules. A launchpad is developed to facilitate the setup of new safes with Safe7579 using the EntryPoint factory.

## How does the Launchpad work

1. **Creation by Factory:**

   - Bundler informs `Entrypoint` to handleUserOps.
   - Entrypoint calls `SenderCreator` to call `SafeProxyFactory`
   - `SenderCreator` requests safeProxy creation from `SafeProxyFactory` using createProxyWithNonce.
   - `SafeProxyFactory` creates a new `SafeProxy` using `create2`.
   - `SafeProxy` is created with a singleton address set to `Launchpad` (!)
   - `InitHash` is stored in the `SafeProxy` storage

2. **Validation Phase:**

   - `Entrypoint` validates user operations in `SafeProxy` via `validateUserOp`.
   - `SafeProxy` delegates validation to `Launchpad`.
   - `Launchpad` ensures the presence of initHash from phase 1 and calls `Safe7579.launchpadValidators`
   - `ValidatorModule` gets installed by `Launchpad`
   - `ValidatorModule` validates user operations and returns `packedValidationData`
   - `Launchpad` returns packedValidationData to `SafeProxy`, `SafeProxy` returns to `Entrypoint`

3. **Execution Phase:**
   - `Entrypoint` triggers `launchpad.setupSafe()` in `SafeProxy`
   - `SafeProxy` delegates the setup to `Launchpad`
   - `LaunchPad` upgradres `SafeStorage.singleton` to `SafeSingleton`
   - `LaunchPad` calls `SafeProxy.setup()` to initialize `SafeSingleton`
   - Setup function in `SafeProxy.setup()` delegatecalls to `lauchpad.initSafe7579`
   - `initSafe7579()` initilazies `Safe7579` with executors, fallbacks, hooks, `IERC7484` registry

This detailed sequence outlines the creation, validation, and execution phases in the system's operation.

```mermaid
sequenceDiagram
participant Bundler
participant Entrypoint
participant SenderCreator
participant SafeProxyFactory
participant SafeProxy
participant SafeSingleton
participant Launchpad
participant Safe7579
participant Registry
participant EventEmitter
participant ValidatorModule
participant Executor

alt Creation by Factory
Bundler->>Entrypoint: handleUserOps
Entrypoint->>SenderCreator: create this initcode
SenderCreator->>+SafeProxyFactory: createProxyWithNonce(launchpad, intializer, salt)
SafeProxyFactory-->>SafeProxy: create2
SafeProxy-->Launchpad: singleton = launchpad
SafeProxyFactory->>+SafeProxy: preValidationSetup (initHash, to, preInit)
SafeProxy-->>+Launchpad: preValidationSetup (initHash, to, preInit) [delegatecall]
Note over Launchpad: sstore initHash
SafeProxy-->>SafeProxyFactory: created
SafeProxyFactory-->>Entrypoint: created sender
end

alt Validation Phase
Entrypoint->>+SafeProxy: validateUserOp
SafeProxy-->>Launchpad: validateUserOp [delegatecall]
Note right of Launchpad: only initializeThenUserOp.selector
Note over Launchpad: require inithash (sload)
Launchpad->>Safe7579: launchpadValidators() [call]
Note over Safe7579: write validator(s) to storage

loop
Launchpad ->> ValidatorModule: onInstall()
Note over Launchpad: emit ModuleInstalled (as SafeProxy)

end
Note over Launchpad: get validator module selection from userOp.nonce
Launchpad ->> ValidatorModule: validateUserOp(userOp, userOpHash)
ValidatorModule ->> Launchpad: packedValidationData
Launchpad-->>SafeProxy: packedValidationData
SafeProxy->>-Entrypoint: packedValidationData
end

alt Execution Phase
Entrypoint->>+SafeProxy: setupSafe
SafeProxy-->>Launchpad: setupSafe [delegatecall]
Note over SafeProxy, Launchpad: sstore safe.singleton == SafeSingleton
Launchpad->>SafeProxy: safe.setup() [call]
SafeProxy->>SafeSingleton: safe.setup() [delegatecall]
Note over SafeSingleton: setup function in Safe has a delegatecall
SafeSingleton-->>Launchpad: initSafe7579WithRegistry [delegatecall]
Launchpad->>SafeProxy: this.enableModule(safe7579)
SafeProxy-->>SafeSingleton: enableModule (safe7579) [delegatecall]
SafeSingleton->>Safe7579: initializeAccountWithRegistry
Note over Safe7579: msg.sender: SafeProxy
alt SetupRegistry
Safe7579-->SafeProxy: exec set attesters on registry
SafeProxy-->>SafeSingleton: exec set attesters on registry
SafeSingleton->>Registry: set attesters (attesters[], threshold)
end
loop installation of modules
Safe7579->>Registry: checkForAccount(SafeProxy, moduleaddr, moduleType)
Safe7579->>SafeProxy: exec call onInstall on module
SafeProxy-->>SafeSingleton: exec call onInstall on Module [delegatecall]
SafeSingleton->>Executor: onInstall() [call]
Safe7579->>SafeProxy: exec EventEmitter
SafeProxy-->>SafeSingleton: exec EventEmitter [delegatecall]
SafeSingleton-->>EventEmitter: emit ModuleInstalled() [delegatecall]
Note over EventEmitter: emit ModuleInstalled() as SafeProxy
end
Safe7579->>SafeProxy: exec done
SafeProxy->-Entrypoint: exec done
end
```

Special thanks to [@nlordell (Safe)](https://github.com/nlordell), who came up with [this technique](https://github.com/safe-global/safe-modules/pull/184)

## How do validations and executions work

In order to call module logic or interact with external contracts, all calls have to be routed over the SafeProxy.
The Safe7579 adapter is an enabled Safe module on the Safe Account, and makes use for `execTransactionFromModule`, to call into external contracts as the Safe Account.

In order to select validator modules, the address of the validator module can be encoded in the userOp.nonce key. If an validator module that was not previously installed, or validator module with address(0) be selected, the Safe's `checkSignature` is used as a fallback.

```mermaid

sequenceDiagram
participant Bundler
participant Entrypoint
participant SafeProxy
participant SafeSingleton
participant Safe7579
participant ValidatorModule
participant ERC20

alt validation with Validator Module
Bundler->>Entrypoint: handleUserOps
Entrypoint->>SafeProxy: validateUserOp()
SafeProxy-->>SafeSingleton: validateUserOp [delegatecall]
Note over SafeSingleton: select Safe7579 as fallback handler
SafeSingleton->>Safe7579: validateUserOp
Note over Safe7579: validator module selection
alt Use Validator Module
Safe7579->>SafeProxy: execTransactionFromModule: call validation module
SafeProxy-->>SafeSingleton: execTransactionFromModule: call validation module [delegatecall]
SafeSingleton->>ValidatorModule: validateUserOp
end
alt Use Safe signatures
Safe7579->>SafeProxy: checkSignatures
SafeProxy-->>SafeSingleton: checkSignatures [delegatecall]
end
end

alt Execution
Bundler->>Entrypoint: handleUserOps
Entrypoint->>SafeProxy: execute()
SafeProxy-->>SafeSingleton: execute [delegatecall]
Note over SafeSingleton: select Safe7579 as fallback handler
SafeSingleton->>Safe7579: execute()
Safe7579->>SafeProxy: execTransactionFromModule: call ERC20.transfer [delegatecall]
SafeProxy-->>SafeSingleton: call ERC20.transfer
SafeSingleton->>ERC20: transfer()
end
```

## Batched Executions

Safe Account's `execTransactionFromModule` do not natively offer the ability to batch multiple calls into a single transaction. Yet one of the core feature of ERC7579 is the ability to validate and make batched executions.
To save Gas, instead of calling `execTransactionFromModule` n times, we are making use of a special multicall contract, that will be delegatecalled by the Safe account.
The same contract is also used, to emit events for onInstall / onUninstall of modules.

## Installation of Modules

## Authors / Credits✨

Thanks to the following people who have contributed to this project:

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://twitter.com/zeroknotsETH/"><img src="https://pbs.twimg.com/profile_images/1639062011387715590/bNmZ5Gpf_400x400.jpg" width="100px;" alt=""/><br /><sub><b>zeroknots (rhinestone)</b></sub></a><br /><a href="https://github.com/zeroknots" title="Code">💻</a></td>

<td align="center"><a href="https://twitter.com/abstractooor"><img src="https://avatars.githubusercontent.com/u/26718079" width="100px;" alt=""/><br /><sub><b>Konrad (rhinestone)</b></sub></a><br /><a href="https://github.com/kopy-kat" title="Spec">📝</a> </td>

<td align="center"><a href="https://twitter.com/NLordello"><img src="https://avatars.githubusercontent.com/u/4210206" width="100px;" alt=""/><br /><sub><b>Nicholas Rodrigues Lordello (Safe)
</b></sub></a><br /><a href="https://github.com/ nlordell" title="Review / Launchpad Idea">📝</a> </td>

  </tr>
</table>

Special Thanks to the Safe Team for their support and guidance in the development of Safe7579.
