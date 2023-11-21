import { IStaticFallbackMethod } from "../../../src/common/FallbackHandler.sol";
import { console2 } from "forge-std/console2.sol";

contract TokenReceiver is IStaticFallbackMethod {
    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes memory result)
    {
        console2.log("Handling fallback");
        bytes4 selector = 0x150b7a02;
        result = abi.encode(selector);
    }
}
