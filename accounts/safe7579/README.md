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

rect rgb(255,179,186)
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

rect rgb(255,179,186)
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
rect rgb(186,225,255)
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
