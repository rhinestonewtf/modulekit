// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RhinestoneAccount as RhinestoneAccountSafe,
    RhinestoneModuleKit as RhinestoneModuleKitSafe,
    RhinestoneModuleKitLib as RhinestoneModuleKitLibSafe
} from "./test/utils/safe-base/RhinestoneModuleKit.sol";

import {
    RhinestoneAccount as RhinestoneAccountBiconomy,
    RhinestoneModuleKit as RhinestoneModuleKitBiconomy,
    RhinestoneModuleKitLib as RhinestoneModuleKitLibBiconomy
} from "./test/utils/biconomy-base/RhinestoneModuleKit.sol";

import {
    RhinestoneAccount as RhinestoneAccountKernel,
    RhinestoneModuleKit as RhinestoneModuleKitKernel,
    RhinestoneModuleKitLib as RhinestoneModuleKitLibKernel
} from "./test/utils/kernel-base/RhinestoneModuleKit.sol";

contract AccountFactorySafe is RhinestoneModuleKitSafe {
    function makeSafe(bytes32 id) public returns (RhinestoneAccountSafe memory accountInstance) {
        accountInstance = makeRhinestoneAccount(id);
    }
}

contract AccountFactoryBiconomy is RhinestoneModuleKitBiconomy {
    function makeBiconomy(bytes32 id)
        public
        returns (RhinestoneAccountBiconomy memory accountInstance)
    {
        accountInstance = makeRhinestoneAccount(id);
    }
}

contract AccountFactoryKernel is RhinestoneModuleKitKernel {
    function makeKernel(bytes32 id)
        public
        returns (RhinestoneAccountKernel memory accountInstance)
    {
        accountInstance = makeRhinestoneAccount(id);
    }
}

contract MultiAccountFactory {
    AccountFactorySafe public safeFactory;
    AccountFactoryBiconomy public biconomyFactory;
    AccountFactoryKernel public kernelFactory;

    constructor() {
        safeFactory = new AccountFactorySafe();
        biconomyFactory = new AccountFactoryBiconomy();
        kernelFactory = new AccountFactoryKernel();
    }

    function makeSafe(bytes32 id) public returns (RhinestoneAccountSafe memory accountInstance) {
        accountInstance = safeFactory.makeSafe(id);
    }

    function makeBiconomy(bytes32 id)
        public
        returns (RhinestoneAccountBiconomy memory accountInstance)
    {
        accountInstance = biconomyFactory.makeBiconomy(id);
    }

    function makeKernel(bytes32 id)
        public
        returns (RhinestoneAccountKernel memory accountInstance)
    {
        accountInstance = kernelFactory.makeKernel(id);
    }
}
