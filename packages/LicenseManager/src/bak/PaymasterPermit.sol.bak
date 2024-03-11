// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "account-abstraction/interfaces/IStakeManager.sol";
import "./BasePaymaster.sol";
import "account-abstraction/core/Helpers.sol";
import { IERC7579Account, Execution } from "@rhinestone/modulekit/src/external/ERC7579.sol";
import {
    CallType, ModeCode, ModeLib, CALLTYPE_SINGLE, CALLTYPE_BATCH
} from "erc7579/lib/ModeLib.sol";
import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";

import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";
import "permit2/src/interfaces/IPermit2.sol";
import { NativeGasRefundExecutor } from "src/NativeGasRefundExecutor.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { FeeClaimLib, IPaymasterPermit } from "./IPaymasterPermit.sol";
import { IWETH } from "./interfaces/IWETH.sol";

uint256 constant PAID_VALIDATOR_ROLE = 1;

contract PaymasterPermit is IPaymasterPermit, BasePaymaster, NativeGasRefundExecutor {
    IPermit2 internal immutable PERMIT2;

    ISwapRouter public immutable uniswap;
    uint256 internal constant SETTLEMENT_GAS = 290_000;
    IWETH internal immutable WETH;

    mapping(bytes32 userOpHash => mapping(address smartAccount => FeeClaim fee)) internal
        $moduleFees;

    mapping(address module => Distribution config) internal $moduleDistributionConfigs;

    constructor(
        IEntryPoint _entrypoint,
        address _permit2,
        address _weth
    )
        BasePaymaster(_entrypoint)
        NativeGasRefundExecutor(_entrypoint)
    {
        PERMIT2 = IPermit2(_permit2);
        WETH = IWETH(_weth);
    }

    // could be hooked via registry resolver
    function setModuleDistribution(
        address module,
        Distribution calldata distribution
    )
        external
        onlyOwner
    {
        $moduleDistributionConfigs[module] = distribution;
    }

    function claimModuleFee(
        address smartaccount,
        bytes32 userOpHash,
        IPermit2.TokenPermissions calldata tokenPermissions
    )
        external
        onlyRoles(PAID_VALIDATOR_ROLE) // granting role could be hooked via registry resolver
    {
        $moduleFees[userOpHash][smartaccount] =
            FeeClaim({ tokenPermissions: tokenPermissions, module: msg.sender });
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        address smartAccount = userOp.sender;

        GasRefundMode gasRefund = GasRefundMode(uint8(bytes1(userOp.paymasterAndData[52:53])));
        bytes calldata paymasterParams = userOp.paymasterAndData[53:];
        uint48 validUntil = uint48(bytes6(paymasterParams[0:6]));
        uint48 validAfter = uint48(bytes6(paymasterParams[6:12]));
        address tokenIn;

        // Support of different ways to pay for gas
        if (gasRefund == GasRefundMode.NATIVE) {
            _gasRefundNative(smartAccount, requiredPreFund);
        } else if (gasRefund == GasRefundMode.NATIVE_WRAPPED) {
            _gasRefundNativeWrapped(smartAccount, userOpHash, requiredPreFund, validUntil);
        } else if (gasRefund == GasRefundMode.SWAP_TOKEN) {
            tokenIn = address(bytes20(paymasterParams[12:32]));

            /**
             * 1. get price from oracle
             * 2. calculate amount of tokenIn required to pay for requiredGas
             * 3. transfer tokenIn to this contract
             * 4. swap tokenIn to ETH
             */
        }

        context = abi.encode(
            gasRefund, requiredPreFund, smartAccount, userOpHash, validUntil, validAfter, tokenIn
        );
    }

    function _gasRefundNativeWrapped(
        address smartAccount,
        bytes32 userOpHash,
        uint256 requiredPreFund,
        uint48 validUntil
    )
        internal
    {
        FeeClaim storage $feeClaim = $moduleFees[userOpHash][smartAccount];
        IPermit2.PermitTransferFrom memory permitTransferFrom = ISignatureTransfer
            .PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(WETH),
                amount: requiredPreFund
            }),
            nonce: 0,
            deadline: validUntil
        });
        IPermit2.SignatureTransferDetails memory transferDetails = ISignatureTransfer
            .SignatureTransferDetails({
            to: address(this),
            requestedAmount: permitTransferFrom.permitted.amount
        });

        PERMIT2.permitTransferFrom({
            permit: permitTransferFrom,
            transferDetails: transferDetails,
            owner: smartAccount,
            signature: abi.encodePacked(address($feeClaim.module), hex"41414141")
        });
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    )
        internal
        virtual
        override
    {
        (
            GasRefundMode gasRefundMode,
            uint256 precharge,
            address smartAccount,
            bytes32 userOpHash,
            uint48 validUntil,
            uint48 validAfter,
            address tokenIn
        ) = abi.decode(context, (GasRefundMode, uint256, address, bytes32, uint48, uint48, address));
        if (gasRefundMode == GasRefundMode.NATIVE) {
            _returnUnneededGas(smartAccount, precharge - actualGasCost - SETTLEMENT_GAS);
        } else if (gasRefundMode == GasRefundMode.NATIVE_WRAPPED) {
            _returnUnneededGasWETH(smartAccount, precharge - actualGasCost - SETTLEMENT_GAS);
        }
        entryPoint.depositTo{ value: address(this).balance }(address(this));
        if (mode == PostOpMode.opSucceeded) {
            _payModuleFee(smartAccount, userOpHash, validUntil);
        }
    }

    function _returnUnneededGasWETH(address smartAccount, uint256 amount) internal {
        IERC20(address(WETH)).transfer(smartAccount, amount);
        WETH.withdraw(IERC20(address(WETH)).balanceOf(address(this)));
    }

    function _payModuleFee(address smartAccount, bytes32 userOpHash, uint48 validUntil) internal {
        // check for distribution mode. Module payments could be issued without swap (in the token
        // requested by the module), or with a swap
        FeeClaim memory feeClaim = $moduleFees[userOpHash][smartAccount];
        Distribution storage distribution = $moduleDistributionConfigs[feeClaim.module];

        feeClaim.tokenPermissions = FeeClaimLib.calculatePercentage({
            tokenPermissions: feeClaim.tokenPermissions,
            percentage: distribution.percentage
        });

        DistributionMode distributionMode = distribution.distributionMode;

        if (distributionMode == DistributionMode.NO_SWAP) {
            IPermit2.PermitTransferFrom memory permitTransferFrom = ISignatureTransfer
                .PermitTransferFrom({
                permitted: feeClaim.tokenPermissions,
                nonce: uint256(userOpHash),
                deadline: validUntil
            });

            IPermit2.SignatureTransferDetails memory transferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                to: distribution.receiver,
                requestedAmount: permitTransferFrom.permitted.amount
            });

            PERMIT2.permitTransferFrom({
                permit: permitTransferFrom,
                transferDetails: transferDetails,
                owner: smartAccount,
                signature: abi.encodePacked(address(feeClaim.module), hex"41414141")
            });
        } else if (distributionMode == DistributionMode.SWAP) {
            address tokenOut = distribution.tokenOut;
            // get price from Feeclaim.tokenPermissions.token to tokenOut
            // calculate amount of tokenOut required to pay for feeClaim.tokenPermissions.amount
            // transfer tokenOut to feeClaim.receiver
        }
    }

    receive() external payable { }
}
