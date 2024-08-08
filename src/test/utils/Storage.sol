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
                        INSTALLED MODULE
//////////////////////////////////////////////////////////////*/

struct InstalledModule {
    uint256 moduleType;
    address moduleAddress;
}

// Adds new address to the installed module array
// The array stores structs with the module type and the module address
function writeInstalledModule(InstalledModule memory module) {
    bytes32 lengthSlot = keccak256(abi.encode("ModuleKit.InstalledModuleSlot"));
    bytes32 elementSlot = keccak256(abi.encode(lengthSlot));
    uint256 moduleType = module.moduleType;
    address moduleAddress = module.moduleAddress;
    assembly {
        // Get the length of the array
        let length := sload(lengthSlot)
        // Update the length of the array
        sstore(lengthSlot, add(length, 1))
        // Calculate the location of the new slot in the array (elementSlot + length * (0x20 * 2))
        let location := add(elementSlot, mul(length, 0x40))
        // Store the module type and address in the new slot
        sstore(location, moduleType)
        sstore(add(location, 0x20), moduleAddress)
    }
}

// Removes all installed modules
function clearInstalledModules() {
    bytes32 lengthSlot = keccak256(abi.encode("ModuleKit.InstalledModuleSlot"));
    bytes32 elementSlot = keccak256(abi.encode(lengthSlot));
    assembly {
        sstore(lengthSlot, 0)
        for { let i := 0 } lt(i, 100) { i := add(i, 1) } {
            sstore(add(elementSlot, mul(i, 0x40)), 0)
            sstore(add(add(elementSlot, mul(i, 0x40)), 0x20), 0)
        }
    }
}

// Removes a specific installed module
function removeInstalledModule(uint256 index) {
    bytes32 lengthSlot = keccak256(abi.encode("ModuleKit.InstalledModuleSlot"));
    bytes32 elementSlot = keccak256(abi.encode(lengthSlot));
    assembly {
        // Get the length of the array
        let length := sload(lengthSlot)
        // Ensure the index is within bounds
        if gt(length, index) {
            // Calculate the location of the slot to remove
            let location := add(elementSlot, mul(index, 0x40))
            // Calculate the location of the last slot
            let lastLocation := add(elementSlot, mul(sub(length, 1), 0x40))
            // Load the last slot
            let lastModuleType := sload(lastLocation)
            let lastModuleAddress := sload(add(lastLocation, 0x20))
            // Store the last slot in the location of the slot to remove
            sstore(location, lastModuleType)
            sstore(add(location, 0x20), lastModuleAddress)
            // Clear the last slot
            sstore(lastLocation, 0)
            sstore(add(lastLocation, 0x20), 0)
            // Update the length of the array
            sstore(lengthSlot, sub(length, 1))
        }
    }
}

// Returns all installed modules as an array of InstalledModule structs
function getInstalledModules() view returns (InstalledModule[] memory modules) {
    bytes32 lengthSlot = keccak256(abi.encode("ModuleKit.InstalledModuleSlot"));
    bytes32 elementSlot = keccak256(abi.encode(lengthSlot));
    assembly {
        // Get the length of the array from storage
        let length := sload(lengthSlot)

        // Each struct is 64 bytes (32 bytes for moduleType and 32 bytes for moduleAddress)
        let structSize := 0x40 // 64 bytes
        let size := mul(length, structSize) // Total size for structs
        let totalSize := add(add(size, 0x40), mul(0x20, length))

        // Allocate memory for the array
        let freeMemoryPtr := mload(0x40)
        modules := freeMemoryPtr

        // Store the length of the array in the first 32 bytes of memory
        mstore(modules, length)

        // Update the free memory pointer to the end of the allocated memory
        mstore(0x40, add(freeMemoryPtr, totalSize))

        // Copy the structs from storage to memory
        for { let i := 0 } lt(i, length) { i := add(i, 1) } {
            // Calculate memory location for this struct
            let structLocation :=
                add(add(freeMemoryPtr, add(0x40, mul(i, structSize))), mul(0x20, length))
            let storageLocation := add(elementSlot, mul(i, structSize)) // Storage location for each
                // struct

            // Load the moduleType and moduleAddress from storage
            let moduleType := sload(storageLocation)
            let moduleAddress := sload(add(storageLocation, 0x20))

            // Store the structLocation into memory
            mstore(add(freeMemoryPtr, add(0x20, mul(i, 0x20))), structLocation)

            // Store the moduleType and moduleAddress into memory
            mstore(structLocation, moduleType)
            mstore(add(structLocation, 0x20), moduleAddress)
        }
    }
}

/*//////////////////////////////////////////////////////////////
                        STRING STORAGE
//////////////////////////////////////////////////////////////*/

function writeString(bytes32 slot, string memory value) {
    bytes memory strBytes = bytes(value);
    uint256 length = strBytes.length;

    // Store the length of the string at the initial slot
    assembly {
        sstore(slot, length)
    }

    // Store the actual string bytes in packed form
    for (uint256 i = 0; i < length; i += 32) {
        bytes32 data;
        for (uint256 j = 0; j < 32 && i + j < length; j++) {
            data |= bytes32(uint256(uint8(strBytes[i + j])) << (248 - j * 8));
        }
        bytes32 charSlot = keccak256(abi.encodePacked(slot, i / 32));
        assembly {
            sstore(charSlot, data)
        }
    }
}

function readString(bytes32 slot) view returns (string memory) {
    uint256 length;

    // Load the length of the string from the initial slot
    assembly {
        length := sload(slot)
    }

    // Allocate memory for the string bytes
    bytes memory strBytes = new bytes(length);

    // Load the actual string bytes from storage in packed form
    for (uint256 i = 0; i < length; i += 32) {
        bytes32 charSlot = keccak256(abi.encodePacked(slot, i / 32));
        bytes32 data;
        assembly {
            data := sload(charSlot)
        }
        for (uint256 j = 0; j < 32 && i + j < length; j++) {
            strBytes[i + j] = bytes1(uint8(uint256(data >> (248 - j * 8))));
        }
    }

    return string(strBytes);
}
