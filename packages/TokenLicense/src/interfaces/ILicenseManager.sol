// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

interface ILicenseManager {
    function domainSeparator() external view returns (bytes32);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               Check for Active License                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct License {
        uint48 validUntil;
        bool autoExtend;
    }

    function hasActiveLicense(address account, address module) external view returns (bool);
    function licenseUntil(address account, address module) external view returns (uint48);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Pay Licenses                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error SubscriptionTooShort();

    event TransactionFee(
        address indexed module,
        address indexed smartAccount,
        address indexed sponsor,
        IERC20 token,
        uint256 amount
    );
    event SubscriptionFee(
        address indexed smartAccount, address indexed module, uint256 amount, uint48 validUntil
    );

    function claimTxFee(
        address smartAccount,
        address sponsor,
        IERC20 token,
        uint256 totalAmount
    )
        external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               Configure Module Monetization                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error UnauthorizedModuleOwner();
    error UnauthorizedModule();

    event NewSplitter(address indexed module, address indexed splitter);
    event NewModuleOwner(address indexed module, address indexed newOwner);
    event NewModuleMonetization(address indexed module);

    function transferOwner(address module, address newOwner) external;
    function updateModuleMonetization(
        address module,
        uint128 pricePerSecond,
        uint32 txPercentage
    )
        external;

    function updateSplitter(
        address module,
        bytes[] calldata signatures,
        address[] calldata newRecipients,
        uint256[] calldata newShares
    )
        external;

    function withdraw(address module) external;

    function killMonetization(address module) external;
    function moduleRegistration(address moduleRecord, address moduleDevBeneficiary) external;
}
