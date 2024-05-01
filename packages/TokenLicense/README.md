# License Manager

License Manager is making use or Uniswap's Permit2 and ERC1271 to enable a smart account to pay for transaction fees and module usage.

## Fee Machines

Fee Machines are external contracts that can be used to calculate equity splits and other fee related calculations.

### Subscription

### Pay per use

### Transaction Fee

## Payments

```mermaid

sequenceDiagram
actor SmartAccount
participant LicenseSessionKey
participant Module
participant LicenseManager
participant FeeMachine
participant Permit2
participant ERC20
actor Dev
actor Beneficiary

alt on Deployment
LicenseSessionKey-->>LicenseManager: get DomainSeparator and cache in bytecode
end

alt Setup

SmartAccount-->>LicenseSessionKey: Installs on account
SmartAccount -->> ERC20: ERC20 approval for Permit2
ERC20 --> Permit2: set approval
Note over SmartAccount: Adds LicenseSessionKey ERC1271 singer to smart account
SmartAccount-->>LicenseSessionKey: allow Module to charge transaction fees
end

alt use paid module
SmartAccount-->>Module: uses module logic
Note over Module: calculate total amount of handled asset value
Module -->> LicenseManager: claimTx fee with total amount
activate LicenseManager

alt Compute equity split
    LicenseManager->>FeeMachine: Request equity split
    activate FeeMachine
    Note over FeeMachine: Checks who beneficiaries are, and what equity split they shall receive

    LicenseManager -->> Dev: Is part in equity
    LicenseManager -->> Beneficiary: Is part in equity
    FeeMachine-->>LicenseManager: Return Transfers
end
deactivate FeeMachine
Note over LicenseManager: checks that total sum of equity splits are not exceeding controlled limit
Note over LicenseManager:  Create EIP712 witness hash for batched tranaction
LicenseManager -->> Permit2: transferWithWithness
Permit2 -->> SmartAccount: ERC1271 validate signature
SmartAccount -->> LicenseSessionKey: forward signature validation
Note over LicenseSessionKey: Validate Witness hash, check if module was enabled by user
LicenseSessionKey -->> Permit2: ERC1271 OK
Permit2 -->> ERC20: TransferFrom
ERC20 -->> Dev: send funds according to equity allocation
ERC20 -->> Beneficiary: send funds according to equity allocation
Permit2 -->> LicenseManager: Tranaction Successful
LicenseManager -->> Module: Transaction paid
deactivate LicenseManager
end
```

## Payments with Swap

```mermaid

sequenceDiagram
actor SmartAccount
participant LicenseSessionKey
participant Module
participant LicenseManager
participant FeeMachine
participant Permit2
participant ERC20TokenIn
participant ERC20TokenOut
participant Uniswap
actor Dev
actor Beneficiary

alt on Deployment
LicenseSessionKey-->>LicenseManager: get DomainSeparator and cache in bytecode
end

alt Setup

SmartAccount-->>LicenseSessionKey: Installs on account
SmartAccount -->> ERC20TokenIn: ERC20 approval for Permit2
ERC20TokenIn --> Permit2: set approval
Note over SmartAccount: Adds LicenseSessionKey ERC1271 singer to smart account
SmartAccount-->>LicenseSessionKey: allow Module to charge transaction fees
end

alt use paid module SWAP
SmartAccount-->>Module: uses module logic
Note over Module: calculate total amount of handled asset value
Module -->> LicenseManager: claimTx fee with total amount
activate LicenseManager

alt Compute equity split
    LicenseManager->>FeeMachine: Request equity split
    activate FeeMachine
    Note over FeeMachine: Checks who beneficiaries are, and what equity split they shall receive

    LicenseManager -->> Dev: Is part in equity
    LicenseManager -->> Beneficiary: Is part in equity
    FeeMachine-->>LicenseManager: Return Transfers
end
deactivate FeeMachine
Note over LicenseManager: checks that total sum of equity splits are not exceeding controlled limit
Note over LicenseManager:  Create EIP712 witness hash for batched tranaction
LicenseManager -->> Uniswap: swap
Uniswap -->> ERC20TokenOut: transfer tokenOut with fee amount
ERC20TokenOut -->> LicenseManager: Transfer
Uniswap-->LicenseManager: Callback uniswapV3Callback
LicenseManager -->> Permit2: transferWithWithness
Permit2 -->> SmartAccount: ERC1271 validate signature
SmartAccount -->> LicenseSessionKey: forward signature validation
Note over LicenseSessionKey: Validate Witness hash, check if module was enabled by user
LicenseSessionKey -->> Permit2: ERC1271 OK
Permit2 -->> ERC20TokenIn: TransferFrom
ERC20TokenIn -->> LicenseManager: Send token
Permit2 -->> LicenseManager: Tranaction Successful
Note over LicenseManager: License manager now has all the funds of tokenIn
LicenseManager -->> ERC20TokenOut: TransferFrom
ERC20TokenOut -->> Dev: send funds according to equity allocation
ERC20TokenOut -->> Beneficiary: send funds according to equity allocation
LicenseManager -->> Module: Transaction paid
LicenseManager --> ERC20TokenIn: Transfer back to Uniswap
ERC20TokenIn --> Uniswap: tranfser
deactivate LicenseManager
end



```
