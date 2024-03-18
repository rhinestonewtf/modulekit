// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

string constant TX_FEE_WITNESS = "LicenseManagerTxFee(address module, uint256 amount)";
bytes32 constant TX_FEE_WITNESS_HASH = keccak256(abi.encodePacked(TX_FEE_WITNESS));

struct LicenseManagerTxFee {
    address module;
    uint256 amount;
}

struct PackedSignature {
    address module;
    bytes signature;
}

struct License {
    uint48 validUntil;
    bool autoExtend;
}

struct ModuleMoneyConf {
    address owner; // developer of module. can be transfered
    address splitter; // receiver of fees
    uint32 txPercentage; // percentage of transaction fees
    uint128 pricePerSecond; // subscription price
    uint32 minSubSeconds; // minimum subscription time
}

error SubscriptionTooShort();

error UnauthorizedModuleOwner();

event NewSplitter(address indexed module, address indexed splitter);

event NewModuleOwner(address indexed module, address indexed newOwner);

event NewModuleMonetization(address indexed module);
