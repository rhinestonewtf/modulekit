import "src/LicenseManager.sol";
import "src/DataTypes.sol";
import "src/lib/Currency.sol";

contract MockOperator {
    using CurrencyLibrary for Currency;

    LicenseManager internal immutable LICENSE_MANAGER;

    constructor(LicenseManager _licenseManager) {
        LICENSE_MANAGER = _licenseManager;
    }

    function simulateSwap(address account, Currency currency, uint256 amount) external {
        LICENSE_MANAGER.transferFrom({
            sender: account,
            receiver: address(this),
            id: currency.toId(),
            amount: amount
        });
        LICENSE_MANAGER.withdraw(currency, amount);
    }
}
