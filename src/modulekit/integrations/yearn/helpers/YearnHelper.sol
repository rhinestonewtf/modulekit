import { MainnetYearnAddresses } from "./MainnetAddresses.sol";
import "../../interfaces/yearn/IYearnRegistry.sol";

contract YearnHelper is MainnetYearnAddresses {
    IYearnRegistry public constant yearnRegistry = IYearnRegistry(YEARN_REGISTRY_ADDR);
}
