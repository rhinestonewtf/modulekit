import "forge-std/interfaces/IERC20.sol";
import "forge-std/interfaces/IERC721.sol";

import { IFallbackMethod } from "modulekit/src/core/ExtensibleFallbackHandler.sol";
import { ERC7579ExecutorBase } from "modulekit/src/Modules.sol";
import "./interfaces/Flashloan.sol";

pragma solidity ^0.8.20;

contract FlashloanLender is IFallbackMethod, ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => uint256) public nonce;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }
    function isInitialized(address smartAccount) external view returns (bool) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        override
        returns (bytes memory result)
    {
        if (data.length < 4) revert();

        bytes4 functionSig = bytes4(data[0:4]);
        if (functionSig == IERC6682.availableForFlashLoan.selector) {
            (address token, uint256 tokenId) = abi.decode(data[4:], (address, uint256));
            result = abi.encode(_availableForFlashLoanERC721(account, token, tokenId));
        } else if (functionSig == IERC6682.flashFee.selector) {
            (address token, uint256 tokenId) = abi.decode(data[4:], (address, uint256));
            result = abi.encode(_flashFee(account, token, tokenId));
        } else if (functionSig == IERC6682.flashFeeToken.selector) {
            result = abi.encode(_flashFeeToken(account));
        } else if (functionSig == IERC3156FlashLender.flashLoan.selector) {
            (
                IERC3156FlashBorrower borrower,
                address token,
                uint256 tokenId,
                bytes memory flashloanData
            ) = abi.decode(data[4:], (IERC3156FlashBorrower, address, uint256, bytes));
            return abi.encode(_flashLoan(account, borrower, token, tokenId, flashloanData));
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a flash loan by lending an NFT and collecting a fee.
     *
     * @param account Address of the lender.
     * @param borrower Address of the borrower implementing IERC3156FlashBorrower.
     * @param token Address of the ERC721 token contract.
     * @param value ID of the NFT.
     * @param data Arbitrary data provided by the borrower.
     * @return True if the flash loan was successful, false otherwise.
     *
     * @dev this is using ERC6682 and modulekit executorManger to lend the token out
     */
    function _flashLoan(
        address account,
        IERC3156FlashBorrower borrower,
        address token,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bool)
    {
        (FlashLoanType flashLoanType,,) = abi.decode(data, (FlashLoanType, bytes, bytes));

        if (flashLoanType == FlashLoanType.ERC721) {
            _execute(
                msg.sender,
                address(token),
                0,
                abi.encodeCall(IERC721.transferFrom, (address(account), address(borrower), value))
            );
        }
        // TODO impl ERC20

        // trigger callback on borrrower
        bool success = borrower.onFlashLoan(account, token, value, 0, data)
            == keccak256("ERC3156FlashBorrower.onFlashLoan");
        if (!success) revert();

        // check that token was sent back
        if (!_availableForFlashLoanERC721({ account: account, token: token, tokenId: value })) {
            revert();
        }
        return true;
    }

    /**
     * @notice Retrieves the borrower fee for a specific NFT.
     * @param account The address of the lender.
     * @param token Address of the ERC721 token contract.
     * @param tokenId ID of the NFT.
     * @return total Fee amount for the specified NFT.
     */
    function _flashFee(
        address account,
        address token,
        uint256 tokenId
    )
        internal
        view
        returns (uint256 total)
    {
        // uint256 tokenOwnerFee = _tokenOwnerFee(account, token, tokenId);
        // total = tokenOwnerFee + calcDevFee(tokenOwnerFee, FEE_PERCENTAGE);
    }

    /**
     * @notice Retrieves the token used for collecting flash loan fees for a specific account.
     * @param account The address of the lender.
     * @return Address of the ERC20 token used for fees.
     */
    function _flashFeeToken(address account) internal view returns (address) { }

    /**
     * @notice Retrieves the borrower fee for a specific NFT.
     * @param account The address of the lender.
     * @param token Address of the ERC721 token contract.
     * @param tokenId ID of the NFT.
     * @return fee amount for the specified NFT.
     */
    function _tokenOwnerFee(
        address account,
        address token,
        uint256 tokenId
    )
        internal
        view
        returns (uint256 fee)
    {
        // fee = _feePerToken[account][token][tokenId];
    }

    /**
     * @notice Checks if a specific NFT is available for flash loan.
     * @param account The address of the potential lender.
     * @param token Address of the ERC721 token contract.
     * @param tokenId ID of the NFT.
     * @return hasToken if the NFT is available for flash loan, false otherwise.
     */
    function _availableForFlashLoanERC721(
        address account,
        address token,
        uint256 tokenId
    )
        internal
        view
        returns (bool hasToken)
    {
        try IERC721(token).ownerOf(tokenId) returns (address holder) {
            hasToken = holder == address(account);
        } catch {
            hasToken = false;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "FlashloanLender";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_EXECUTOR;
    }
}
