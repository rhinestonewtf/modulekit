// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/*//////////////////////////////////////////////////////////////
                        EXPECT REVERT
//////////////////////////////////////////////////////////////*/

function writeExpectRevert(uint256 value) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    assembly {
        sstore(slot, value)
    }
}

function getExpectRevert() view returns (uint256 value) {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    assembly {
        value := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                        GAS IDENTIFIER
//////////////////////////////////////////////////////////////*/

function writeGasIdentifier(string memory id) {
    bytes32 slot = keccak256("ModuleKit.GasIdentifierSlot");
    assembly {
        sstore(slot, id)
    }
}

function getGasIdentifier() view returns (string memory id) {
    bytes32 slot = keccak256("ModuleKit.GasIdentifierSlot");
    assembly {
        id := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                        SIMULATE OP
//////////////////////////////////////////////////////////////*/

function writeSimulateUserOp(bool value) {
    bytes32 slot = keccak256("ModuleKit.SimulateUserOp");
    assembly {
        sstore(slot, value)
    }
}

function getSimulateUserOp() view returns (bool value) {
    bytes32 slot = keccak256("ModuleKit.SimulateUserOp");
    assembly {
        value := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                        ACCOUNT ENV
//////////////////////////////////////////////////////////////*/

function writeAccountEnv(string memory env, address factory, address helper) {
    bytes32 envSlot = keccak256("ModuleKit.AccountTypeSlot");
    bytes32 factorySlot = keccak256("ModuleKit.AccountFactorySlot");
    bytes32 helperSlot = keccak256("ModuleKit.HelperSlot");
    bytes32 envHash = keccak256(abi.encodePacked(env));
    assembly {
        sstore(envSlot, envHash)
        sstore(factorySlot, factory)
        sstore(helperSlot, helper)
    }
}

function getAccountEnv() view returns (bytes32 env, address factory, address helper) {
    bytes32 envSlot = keccak256("ModuleKit.AccountTypeSlot");
    bytes32 factorySlot = keccak256("ModuleKit.AccountFactorySlot");
    bytes32 helperSlot = keccak256("ModuleKit.HelperSlot");
    assembly {
        env := sload(envSlot)
        factory := sload(factorySlot)
        helper := sload(helperSlot)
    }
}

/*//////////////////////////////////////////////////////////////
                            IS INIT
//////////////////////////////////////////////////////////////*/

function writeIsInit(bool value) {
    bytes32 slot = keccak256("ModuleKit.IsInitSlot");
    assembly {
        sstore(slot, value)
    }
}

function getIsInit() view returns (bool value) {
    bytes32 slot = keccak256("ModuleKit.IsInitSlot");
    assembly {
        value := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                            ACCOUNT TYPE
//////////////////////////////////////////////////////////////*/

function writeAccountType(string memory accountType) {
    bytes32 slot = keccak256("ModuleKit.AccountTypeSlot");
    assembly {
        sstore(slot, accountType)
    }
}

function getAccountType() view returns (bytes32 accountType) {
    bytes32 slot = keccak256("ModuleKit.AccountTypeSlot");
    assembly {
        accountType := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                            FACTORY
//////////////////////////////////////////////////////////////*/

function writeFactory(address factory, string memory factoryType) {
    bytes32 slot = keccak256(abi.encodePacked("ModuleKit.", factoryType, "FactorySlot"));
    assembly {
        sstore(slot, factory)
    }
}

function getFactory(string memory factoryType) view returns (address factory) {
    bytes32 slot = keccak256(abi.encodePacked("ModuleKit.", factoryType, "FactorySlot"));
    assembly {
        factory := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                            HELPER
//////////////////////////////////////////////////////////////*/

function writeHelper(address helper, string memory helperType) {
    bytes32 slot = keccak256(abi.encodePacked("ModuleKit.", helperType, "HelperSlot"));
    assembly {
        sstore(slot, helper)
    }
}

function getHelper(string memory helperType) view returns (address helper) {
    bytes32 slot = keccak256(abi.encodePacked("ModuleKit.", helperType, "HelperSlot"));
    assembly {
        helper := sload(slot)
    }
}
