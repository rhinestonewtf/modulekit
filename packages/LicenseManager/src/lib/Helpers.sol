import { IFeeMachine } from "../interfaces/IFeeMachine.sol";
import { IProtocolController } from "../interfaces/IProtocolController.sol";
import "../DataTypes.sol";
import "./Currency.sol";

library Helpers {
    using CurrencyLibrary for Currency;

    function getSplits(
        IFeeMachine feeMachine,
        address module,
        ClaimTransaction calldata claim
    )
        internal
        returns (Split[] memory)
    {
        if (address(feeMachine) == address(0)) return new Split[](0);
        return feeMachine.split({ module: module, claim: claim });
    }

    function settleReceiverFees(
        address module,
        ModuleRecord storage $moduleRecord,
        ClaimTransaction calldata claim,
        function (address receiver, uint256 id, uint256 amount) internal mintFn
    )
        internal
        returns (uint256 total)
    {
        // get FeeMachine for Module

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        if (address(feeMachine) == address(0)) return 0;

        // get splits from fee machine
        Split[] memory splits = feeMachine.split({ module: module, claim: claim });

        uint256 currencyId = claim.currency.toId();

        uint256 length = splits.length;
        for (uint256 i; i < length; i++) {
            mintFn({ receiver: splits[i].receiver, id: currencyId, amount: splits[i].amount });
            total += splits[i].amount;
        }
    }

    // function settleProtocolFees(
    //     IProtocolController controller,
    //     address module,
    //     ClaimType claimType,
    //     uint256 total,
    //     function (address receiver, uint256 id, uint256 amount) mintFn
    // )
    //     internal
    //     returns (uint256 newTotal)
    // {
    //     if (address(controller) == address(0)) return total;
    //
    //     (uint256 bps, address receiver) = controller.protocolFeeForModule({
    //         module: module,
    //         feeMachine: feeMachine,
    //         claimType: claimType
    //     });
    //
    //     uint256 protocolFee = (total * bps) / 10_000;
    //     mintFn({ receiver: receiver, id: claim.currency.toId(), amount: protocolFee });
    // }
}
