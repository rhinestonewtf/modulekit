# License Manager

## Transaction Payments

```mermaid

sequenceDiagram
actor SmartAccount
participant TransactionSigner
participant Module
participant LicenseManager
participant FeeMachine
participant Permit2
participant ERC20
actor Dev
actor Beneficiary

alt on Deployment
TransactionSigner-->>LicenseManager: get DomainSeparator and cache in bytecode
end

alt Setup

SmartAccount-->>TransactionSigner: Installs on account
SmartAccount -->> ERC20: ERC20 approval for Permit2
ERC20 --> Permit2: set approval
Note over SmartAccount: Adds TransactionSigner ERC1271 singer to smart account
SmartAccount-->>TransactionSigner: allow Module to charge transaction fees
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
SmartAccount -->> TransactionSigner: forward signature validation
Note over TransactionSigner: Validate Witness hash, check if module was enabled by user
TransactionSigner -->> Permit2: ERC1271 OK
Permit2 -->> ERC20: TransferFrom
ERC20 -->> Dev: send funds according to equity allocation
ERC20 -->> Beneficiary: send funds according to equity allocation
Permit2 -->> LicenseManager: Tranaction Successful
LicenseManager -->> Module: Transaction paid
deactivate LicenseManager
end
```
