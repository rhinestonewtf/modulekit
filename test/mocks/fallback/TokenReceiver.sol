import { IStaticFallbackMethod } from "../../../src/common/FallbackHandler.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC721TokenReceiver } from "forge-std/interfaces/IERC721.sol";

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
        bytes4 selector = IERC721TokenReceiver.onERC721Received.selector;
        result = abi.encode(selector);
    }
}
