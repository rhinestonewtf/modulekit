sequenceDiagram
participant Sender
participant Entrypoint
participant SenderCreator
participant SafeProxyFactory
participant SafeProxy
participant SafeSingleton
participant Launchpad
participant Safe7579

rect rgb(255,179,186)
Sender->>Entrypoint: handleUserOps
Entrypoint->>SenderCreator: create this initcode
SenderCreator->>+SafeProxyFactory: createProxyWithNonce(launchpad, intializer, salt)
SafeProxyFactory-->>SafeProxy: create2
SafeProxy-->Launchpad: singleton = launchpad
SafeProxyFactory->>+SafeProxy: preValidationSetup (initHash, to, preInit)
SafeProxy-->>+Launchpad: preValidationSetup (initHash, to, preInit) [delegatecall]
Note over Launchpad: sstore initHash
Launchpad ->> Registry: set Attesters [call]
Note right of Registry: store attesters
SafeProxy-->>SafeProxyFactory: created
SafeProxyFactory-->>Entrypoint: created sender
end

rect rgb(255,179,186)
Entrypoint->>+SafeProxy: validateUserOp
SafeProxy-->>Launchpad: validateUserOp [delegatecall]
Note right of Launchpad: only initializeThenUserOp.selector
Note over Launchpad: restore and check inithash (sload)
Launchpad-->>SafeProxy: packedValid
SafeProxy->>-Entrypoint: packedValid
end
rect rgb(186,225,255)
Entrypoint->>+SafeProxy: initializeThenUserOp
SafeProxy-->>Launchpad: initializeThenUserOp [delegatecall]
Note over SafeProxy, Launchpad: sstore safe.singleton == SafeSingleton
Launchpad->>SafeProxy: safe.setup() [call]
SafeProxy->>SafeSingleton: safe.setup() [delegatecall]
Note over SafeSingleton: setup function in Safe has a delegatecall
SafeSingleton-->>Launchpad: initSafe7579 [delegatecall]
Launchpad->>SafeProxy: this.enableModule(safe7579)
SafeProxy-->>SafeSingleton: enableModule (safe7579) [delegatecall]
Launchpad->>Safe7579: initializeAccount
Note over Safe7579: msg.sender: SafeProxy
Safe7579->SafeProxy: exec done
SafeProxy->-Entrypoint: exec done
end
