// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILicenseManager {
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

    function approvalSubscription(address module, uint256 amount) external;
    function signedSubscription(
        address module,
        uint256 amount,
        bytes calldata signature
    )
        external;
    function approvalTxFee(address smartAccount, uint256 totalAmount) external;
    function signedTxFee(
        address smartAccount,
        uint256 totalAmount,
        bytes calldata signature
    )
        external;
    function permitTxFee(
        address smartAccount,
        uint256 totalAmount,
        bytes calldata signature
    )
        external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               Configure Module Monetization                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error UnauthorizedModuleOwner();

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
