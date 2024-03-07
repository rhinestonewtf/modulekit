// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "account-abstraction/interfaces/IStakeManager.sol";
import "account-abstraction/core/BasePaymaster.sol";
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

address constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

interface IOracle {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

enum GasMode {
    SELF,
    TOKEN,
    DELEGATE,
    STAKE
}

contract FeePayMaster is BasePaymaster, ERC7579ExecutorBase {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;
    using SafeTransferLib for address;

    uint256 constant REFUND_POSTOP_COST = 240_000;

    uint256 priceMarkup = 1e6;
    /// @dev The oracle contract used to fetch the latest ERC20 to USD token prices.
    IOracle public immutable TOKEN_ORACLE;

    /// @dev The Oracle contract used to fetch the latest native asset (e.g. ETH) to USD prices.
    IOracle public immutable NATIVE_ASSET_ORACLE;

    IERC20 public immutable FEE_TOKEN;
    uint256 public immutable FEE_TOKEN_DECIMALS;

    uint256 public constant PRICE_DENOMINATOR = 1e6;
    /// @dev The oracle price is stale.

    error OraclePriceStale();

    /// @dev The oracle price is less than or equal to zero.
    error OraclePriceZero();

    /// @dev The oracle decimals are not set to 8.
    error OracleDecimalsInvalid();

    error OracleRoundIncomplete();

    struct FeePayment {
        IERC20 token;
        uint256 amount;
        address receiver;
    }

    mapping(bytes32 userOpHash => mapping(address smartAccount => FeePayment fee)) internal $toPay;

    constructor(
        IEntryPoint _entrypoint,
        IERC20 feeToken,
        uint256 feeTokenDecimals,
        IOracle tokenOracle,
        IOracle nativeAssetOracle
    )
        BasePaymaster(_entrypoint)
    {
        TOKEN_ORACLE = tokenOracle;
        NATIVE_ASSET_ORACLE = nativeAssetOracle;
        FEE_TOKEN = feeToken;
        FEE_TOKEN_DECIMALS = feeTokenDecimals;
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
        address account = userOp.sender;

        GasMode mode = GasMode(uint8(bytes1(userOp.paymasterAndData[52:53])));
        bytes calldata paymasterParams = userOp.paymasterAndData[53:];
        uint48 validUntil = uint48(bytes6(paymasterParams[0:6]));
        uint48 validAfter = uint48(bytes6(paymasterParams[6:12]));

        // uint192 tokenPrice = getPrice();
        uint256 amount;

        {
            uint256 maxFeePerGas = UserOperationLib.unpackMaxFeePerGas(userOp);
            // tokenAmount = (maxCost + (REFUND_POSTOP_COST) * maxFeePerGas) * priceMarkup *
            // tokenPrice
            //     / (1e18 * PRICE_DENOMINATOR);
        }

        if (mode == GasMode.SELF) {
            uint256 maxFeePerGas = UserOperationLib.unpackMaxFeePerGas(userOp);
            // amount = (REFUND_POSTOP_COST * maxFeePerGas);
            amount = requiredPreFund + (REFUND_POSTOP_COST * maxFeePerGas);
            // gas refund
            console2.log("amount", amount);
            _gasRefund(IERC7579Account(account), amount);
        }

        FeePayment memory fee = $toPay[userOpHash][account];
        _payFee(IERC7579Account(account), fee.receiver, FEE_TOKEN, fee.amount);
        //
        // SafeTransferLib.safeTransferFrom(
        //     address(FEE_TOKEN), userOp.sender, address(this), tokenAmount
        // );
        context = abi.encode(account, amount, uint256(1));
        validationData = _packValidationData(false, validUntil, validAfter);
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
        (address userOpSender, uint256 preCharge,) =
            abi.decode(context, (address, uint256, uint256));
        if (preCharge > actualGasCost) {
            // If the initially provided token amount is greater than the actual amount needed,
            // refund the difference
            IStakeManager(ENTRYPOINT_ADDR).withdrawTo(
                payable(userOpSender), preCharge - actualGasCost - REFUND_POSTOP_COST
            );
        } else if (preCharge < actualGasCost) {
            // Attempt to cover Paymaster's gas expenses by withdrawing the 'overdraft' from the
            // client
            // If the transfer reverts also revert the 'postOp' to remove the incentive to cheat
            _gasRefund(IERC7579Account(userOpSender), actualGasCost - preCharge);
        }
    }

    function claimFee(
        bytes32 userOpHash,
        address smartAccount,
        address receiver,
        IERC20 token,
        uint256 amount
    )
        external
    {
        $toPay[userOpHash][smartAccount] =
            FeePayment({ token: token, amount: amount, receiver: receiver });
    }

    function _payFee(
        IERC7579Account smartAccount,
        address receiver,
        IERC20 token,
        uint256 amount
    )
        internal
    {
        address(token).safeTransferFrom(address(smartAccount), receiver, amount);
    }

    function _gasRefund(IERC7579Account smartAccount, uint256 amount) internal {
        smartAccount.executeFromExecutor(
            ModeCode.wrap(0),
            ExecutionLib.encodeSingle({
                target: address(ENTRYPOINT_ADDR),
                value: amount,
                callData: abi.encodeCall(IStakeManager.depositTo, (address(this)))
            })
        );
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }

    /// @notice Fetches the latest token price.
    /// @return price The latest token price fetched from the oracles.
    function getPrice() public view returns (uint192) {
        uint192 tokenPrice = _fetchPrice(TOKEN_ORACLE);
        uint192 nativeAssetPrice = _fetchPrice(NATIVE_ASSET_ORACLE);
        uint192 price = nativeAssetPrice * uint192(FEE_TOKEN_DECIMALS) / tokenPrice;

        return price;
    }

    /// @notice Fetches the latest price from the given oracle.
    /// @dev This function is used to get the latest price from the tokenOracle or
    /// nativeAssetOracle.
    /// @param _oracle The oracle contract to fetch the price from.
    /// @return price The latest price fetched from the oracle.
    function _fetchPrice(IOracle _oracle) internal view returns (uint192 price) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            _oracle.latestRoundData();
        if (answer <= 0) {
            revert OraclePriceZero();
        }
        // 2 days old price is considered stale since the price is updated every 24 hours
        if (updatedAt < block.timestamp - 60 * 60 * 24 * 2) {
            revert OracleRoundIncomplete();
        }
        if (answeredInRound < roundId) {
            revert OraclePriceStale();
        }
        price = uint192(int192(answer));
    }
}
