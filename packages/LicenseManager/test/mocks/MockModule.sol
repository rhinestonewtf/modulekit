import "src/LicenseManager.sol";

contract MockModule {
    LicenseManager internal immutable LICENSE_MANAGER;

    constructor(LicenseManager _licenseManager) {
        LICENSE_MANAGER = _licenseManager;
    }

    function triggerClaim(ClaimTransaction calldata claim) external {
        LICENSE_MANAGER.settleTransaction(claim);
    }
}
