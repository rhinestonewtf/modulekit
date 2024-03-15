// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDistributor {
    struct ModuleMonetization {
        address owner;
        address beneficiary;
        uint128 pricePerSecond;
    }

    struct FeeDistribution {
        address module;
        uint256 amount;
    }

    function underlyingToken() external view returns (address);

    function distribute(FeeDistribution calldata distr) external;
}
