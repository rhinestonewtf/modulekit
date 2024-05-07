import "../interfaces/IProtocolController.sol";
import { Ownable } from "solady/auth/Ownable.sol";

abstract contract Protocol is Ownable {
    function protocolController() public returns (IProtocolController controller) {
        return IProtocolController(owner());
    }

    function addProtocolFee(
        address account,
        Currency currency,
        address module,
        IFeeMachine feeMachine,
        ClaimType claimType,
        uint256 total
    )
        internal
        returns (uint256 protocolFee, uint256 newTotal, address beneficiary)
    {
        IProtocolController controller = protocolController();
        if (controller == IProtocolController(address(0))) return (0, total, address(0));
        uint256 bps;
        (bps, beneficiary) = controller.protocolFeeForModule({
            module: module,
            feeMachine: feeMachine,
            claimType: claimType
        });

        // TODO: check max bps
        protocolFee = (total * bps) / 10_000;

        newTotal = total + protocolFee;
    }
}
