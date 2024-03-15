import "./LicenseRouter.sol";

struct ModuleWitness {
    uint256 value;
    address module;
}

contract Module {
    LicenseRouter public licenseRouter;

    string public constant MODULE_WITNESS_TYPE = ("ModuleWitness(uint value, address module)");

    constructor(address _licenseRouter) {
        licenseRouter = LicenseRouter(_licenseRouter);
    }

    modifier onlyActiveLicense() {
        if (licenseRouter.hasActiveLicenses(msg.sender, address(this)) == false) {
            revert("Module: no active license");
        }
        _;
    }

    function mockFeature() public onlyActiveLicense returns (uint256) {
        return 1337;
    }

    function initSub(bytes calldata signature) public {
        licenseRouter.mintLicense(msg.sender, address(this), signature);
    }
}
