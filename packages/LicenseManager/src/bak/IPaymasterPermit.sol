// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";

interface IPaymasterPermit {
    enum DistributionMode {
        NO_SWAP,
        SWAP
    }

    struct Distribution {
        DistributionMode distributionMode;
        uint64 percentage;
        address receiver;
        address tokenOut;
    }

    enum GasRefundMode {
        NATIVE,
        NATIVE_WRAPPED,
        SWAP_TOKEN,
        DELEGATE,
        STAKE
    }

    struct FeeClaim {
        /**
         *  address token,
         *  uint256 amount
         */
        IPermit2.TokenPermissions tokenPermissions;
        address module;
    }

    function claimModuleFee(
        address smartaccount,
        bytes32 userOpHash,
        IPermit2.TokenPermissions calldata tokenPermissions
    )
        external;
}

library FeeClaimLib {
    function calculatePercentage(
        IPermit2.TokenPermissions memory tokenPermissions,
        uint64 percentage
    )
        internal
        returns (IPermit2.TokenPermissions memory)
    {
        tokenPermissions.amount = tokenPermissions.amount * percentage / (100 * 1e6);
        return tokenPermissions;
    }
}
