// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

string constant TX_FEE_WITNESS =
    "LicenseManagerTxFee(address module, address payer, uint256 amount, uint32 txPercentage)";
bytes32 constant TX_FEE_WITNESS_TYPEHASH = keccak256(abi.encodePacked(TX_FEE_WITNESS));

string constant SUBSCRIPTION_WITNESS = "LicenseManagerSubscription(address module, uint256 amount)";
bytes32 constant SUBSCRIPTION_WITNESS_TYPEHASH = keccak256(abi.encodePacked(SUBSCRIPTION_WITNESS));

struct LicenseManagerTxFee {
    address module;
    address sponsor;
    uint256 amount;
    bps txPercentage;
}

struct LicenseManagerSubscription {
    address module;
    address sponsor;
    uint256 amount;
}

struct PackedSignature {
    address module;
    bytes signature;
}

struct License {
    uint48 validUntil;
    uint48 renewalSeconds;
}

struct ModuleMoneyConf {
    address owner; // developer of module. can be transfered
    address splitter; // receiver of fees
    IERC20 token;
    uint32 txPercentage; // percentage of transaction fees
    uint128 pricePerSecond; // subscription price
    uint32 minSubSeconds; // minimum subscription time
}

struct ShareholderRecord {
    address addr;
    uint32 equity;
}

struct ModuleRecordTxFee {
    bps txPercentage;
    address[] shareholders;
    bps[] equities;
}

error SubscriptionTooShort();

error UnauthorizedModuleOwner();

event NewSplitter(address indexed module, address indexed splitter);

event NewModuleOwner(address indexed module, address indexed newOwner);

event NewModuleMonetization(address indexed module);

type bps is uint32;

using { bpsEq as == } for bps global;
using { bpsNeq as != } for bps global;
using { bpsBt as > } for bps global;
using { bpsLt as < } for bps global;

function bpsEq(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) == bps.unwrap(val2);
}

function bpsNeq(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) != bps.unwrap(val2);
}

function bpsBt(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) > bps.unwrap(val2);
}

function bpsLt(bps val1, bps val2) pure returns (bool) {
    return bps.unwrap(val1) < bps.unwrap(val2);
}

library MathLib {
    uint256 internal constant dec = 10_000;

    function percent(uint256 amount, bps _bps) internal pure returns (uint256 _result) {
        require((amount * bps.unwrap(_bps)) >= dec, "Invalid BPS");
        return amount * bps.unwrap(_bps) / dec;
    }
}
