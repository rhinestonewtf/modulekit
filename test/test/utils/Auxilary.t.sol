// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { AuxiliaryFactory, IBootstrap, Auxiliary } from "../../../src/test/utils/Auxiliary.sol";
import { SessionKeyManager } from "../../../src/core/SessionKeyManager.sol";

contract AuxilaryTest is Test, AuxiliaryFactory {
    function setUp() public {
        init();
    }

    function exposed_makeAuxiliary(
        address _rhinestoneManager,
        IBootstrap _bootstrap
    )
        public
        returns (Auxiliary memory aux)
    {
        SessionKeyManager sessionKeyManager = new SessionKeyManager(48,164);
        return makeAuxiliary(_rhinestoneManager, _bootstrap, sessionKeyManager);
    }

    function testMakeAuxiliary() public {
        address rhinestoneManager = address(0x4242424242);
        Auxiliary memory aux = exposed_makeAuxiliary(rhinestoneManager, bootstrap);

        assertEq(address(aux.entrypoint), address(entrypoint));
        assertEq(address(aux.rhinestoneManager), address(rhinestoneManager));
        assertEq(address(aux.executorManager), address(executorManager));
        assertEq(address(aux.compConditionManager), address(compConditionManager));
        assertEq(address(aux.rhinestoneBootstrap), address(bootstrap));
        assertEq(address(aux.rhinestoneFactory), address(mockRhinestoneFactory));
        assertEq(address(aux.validator), address(mockValidator));
        assertEq(address(aux.registry), address(mockRegistry));
    }
}
