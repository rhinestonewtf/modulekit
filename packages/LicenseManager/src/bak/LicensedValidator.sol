import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";
import { IPaymasterPermit } from "./IPaymasterPermit.sol";

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";
import "forge-std/interfaces/IERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";

contract LicensedValidator is ERC7579ValidatorBase {
    address immutable FEE_RECIEPIENT;
    address immutable FEE_TOKEN;

    error InvalidPaymaster();

    constructor(address _feeRecipient, address _feeToken) {
        FEE_RECIEPIENT = _feeRecipient;
        FEE_TOKEN = _feeToken;
    }

    function _payModuleFee(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 amount
    )
        internal
    {
        IPaymasterPermit paymaster =
            IPaymasterPermit(address(bytes20(userOp.paymasterAndData[0:20])));
        if (address(paymaster) == address(0)) revert InvalidPaymaster();
        paymaster.claimModuleFee({
            userOpHash: userOpHash,
            smartaccount: address(userOp.sender),
            tokenPermissions: ISignatureTransfer.TokenPermissions({ token: FEE_TOKEN, amount: amount })
        });
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        _payModuleFee(userOp, userOpHash, 1337);
        return VALIDATION_SUCCESS;
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        return EIP1271_SUCCESS;
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
