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
    writeString(slot, id);
}

function getGasIdentifier() view returns (string memory id) {
    bytes32 slot = keccak256("ModuleKit.GasIdentifierSlot");
    id = readString(slot);
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
    bytes32 accountTypeHash = keccak256(abi.encodePacked(accountType));
    assembly {
        sstore(slot, accountTypeHash)
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
    bytes32 slot = keccak256(abi.encode("ModuleKit.", factoryType, "FactorySlot"));
    assembly {
        sstore(slot, factory)
    }
}

function getFactory(string memory factoryType) view returns (address factory) {
    bytes32 slot = keccak256(abi.encode("ModuleKit.", factoryType, "FactorySlot"));
    assembly {
        factory := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                            HELPER
//////////////////////////////////////////////////////////////*/

function writeHelper(address helper, string memory helperType) {
    bytes32 slot = keccak256(abi.encode("ModuleKit.", helperType, "HelperSlot"));
    assembly {
        sstore(slot, helper)
    }
}

function getHelper(string memory helperType) view returns (address helper) {
    bytes32 slot = keccak256(abi.encode("ModuleKit.", helperType, "HelperSlot"));
    assembly {
        helper := sload(slot)
    }
}

/*//////////////////////////////////////////////////////////////
                        STRING STORAGE
//////////////////////////////////////////////////////////////*/

function writeString(bytes32 slot, string memory value) {
    bytes memory strBytes = bytes(value);
    uint256 length = strBytes.length;
    assembly {
        sstore(slot, length) // Store the length of the string
    }
    for (uint256 i = 0; i < length; i++) {
        bytes32 charSlot = keccak256(abi.encodePacked(slot, i));
        assembly {
            sstore(charSlot, mload(add(add(strBytes, 0x20), i)))
        }
    }
}

function readString(bytes32 slot) view returns (string memory) {
    uint256 length;
    assembly {
        length := sload(slot)
    }
    bytes memory strBytes = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
        bytes32 charSlot = keccak256(abi.encodePacked(slot, i));
        bytes32 charData;
        assembly {
            charData := sload(charSlot)
        }
        strBytes[i] = bytes1(charData);
    }
    return string(strBytes);
}
