import "../interfaces/IProtocolController.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { IProtocolController } from "../interfaces/IProtocolController.sol";

abstract contract ProtocolConfig is Ownable {
    function protocolController() public view returns (IProtocolController controller) {
        return IProtocolController(owner());
    }

    constructor(IProtocolController protocolController) {
        _initializeOwner(address(protocolController));
    }

    modifier onlyProtocolController() {
        if (msg.sender != address(protocolController())) revert Unauthorized();
        _;
    }

    function getProtocolFee(
        address account,
        Currency currency,
        address module,
        IFeeMachine feeMachine,
        ClaimType claimType,
        uint256 total
    )
        internal
        view
        returns (uint256 protocolFee, address receiver)
    {
        IProtocolController controller = protocolController();
        if (controller == IProtocolController(address(0))) return (0, address(0));
        uint256 bps;
        (bps, receiver) = controller.protocolFeeForModule({
            account: account,
            module: module,
            feeMachine: feeMachine,
            feeMachineAmount: total,
            currency: currency,
            claimType: claimType
        });

        protocolFee = (total * bps) / 10_000;
    }
}
