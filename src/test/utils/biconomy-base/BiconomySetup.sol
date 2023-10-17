// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Auxiliary, AuxiliaryLib } from "../Auxiliary.sol";
import { RhinestoneAccount } from "./RhinestoneModuleKit.sol";
import { IBootstrap, InitialModule } from "../../../common/IBootstrap.sol";

library BiconomyHelpers {
    function accountInitCode(RhinestoneAccount memory instance) internal returns (bytes memory) {
        return abi.encodePacked(
            instance.accountFlavor.accountFactory,
            abi.encodeWithSelector(
                instance.accountFlavor.accountFactory.deployCounterFactualAccount.selector,
                instance.initialAuthModule,
                abi.encodeWithSignature("initForSmartAccount(address)", instance.initialOwner.addr),
                instance.salt
            )
        );
    }
}
