// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/*//////////////////////////////////////////////////////////////
                        EXPECT REVERT
//////////////////////////////////////////////////////////////*/

function writeExpectRevert(bytes memory message) {
    uint256 value = 1;
    bytes32 slot = keccak256("ModuleKit.ExpectMessageSlot");

    if (message.length > 0) {
        value = 2;
        assembly {
            sstore(slot, message)
        }
    }

    slot = keccak256("ModuleKit.ExpectSlot");
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

function getExpectRevertMessage() view returns (bytes memory data) {
    bytes32 slot = keccak256("ModuleKit.ExpectMessageSlot");
    assembly {
        data := sload(slot)
    }
}

function clearExpectRevert() {
    bytes32 slot = keccak256("ModuleKit.ExpectSlot");
    assembly {
        sstore(slot, 0)
    }

    slot = keccak256("ModuleKit.ExpectMessageSlot");
    assembly {
        sstore(slot, 0)
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
                        STORAGE COMPLIANCE
//////////////////////////////////////////////////////////////*/

function writeStorageCompliance(bool value) {
    bytes32 slot = keccak256("ModuleKit.StorageCompliance");
    assembly {
        sstore(slot, value)
    }
}

function getStorageCompliance() view returns (bool value) {
    bytes32 slot = keccak256("ModuleKit.StorageCompliance");
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

// Adds new address to the installed module linked list for the given account
// The list is stored in storage as a linked list in the following format:
// ---------------------------------------------------------------------
// | Slot                                                     | Value  |
// |----------------------------------------------------------|--------|
// | keccak256(abi.encode("ModuleKit.InstalledModuleSlot.")); | length |
// | keccak256(abi.encode("ModuleKit.InstalledModuleHead.")); | head   |
// | keccak256(abi.encode("ModuleKit.InstalledModuleTail.")); | tail   |
// | keccak256(abi.encode(lengthSlot)) - initially X          | element|
// ---------------------------------------------------------------------
//
// The elements are stored in the following way:
// --------------------------
// | Slot      | Value      |
// |------------------------|
// | X         | moduleType |
// | X + 0x20  | moduleAddr |
// | X + 0x40  | prev       |
// | X + 0x60  | next       |
// --------------------------
function writeInstalledModule(InstalledModule memory module, address account) {
    bytes32 lengthSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleSlot.", keccak256(abi.encodePacked(account)))
    );
    bytes32 headSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleHead.", keccak256(abi.encodePacked(account)))
    );
    bytes32 tailSlot =
        keccak256(abi.encode("ModuleKit.InstalledModuleTail", keccak256(abi.encodePacked(account))));
    bytes32 elementSlot = keccak256(abi.encode(lengthSlot));
    uint256 moduleType = module.moduleType;
    address moduleAddress = module.moduleAddress;
    assembly {
        // Get the length of the array
        let length := sload(lengthSlot)
        let nextSlot
        let oldTail
        switch iszero(length)
        case 1 {
            // If length is zero, set element slot to head and tail
            sstore(headSlot, elementSlot)
            sstore(tailSlot, elementSlot)
            oldTail := elementSlot
            nextSlot := elementSlot
        }
        default {
            oldTail := sload(tailSlot)
            // Set the new elemeont slot to the old tail + 0x80
            elementSlot := add(oldTail, 0x80)
            // Set the old tail next slot to the new element slot
            sstore(add(oldTail, 0x60), elementSlot)
            // Update tailSlot to point to the new element slot
            sstore(tailSlot, elementSlot)
            // Set nextSlot to the head slot
            nextSlot := sload(headSlot)
        }
        // Update the length of the list
        sstore(lengthSlot, add(length, 1))
        // Store the module type and address in the new slot
        sstore(elementSlot, moduleType)
        sstore(add(elementSlot, 0x20), moduleAddress)
        // Store the old tail as the prev slot
        sstore(add(elementSlot, 0x40), oldTail)
        // Store the head as the next slot
        sstore(add(elementSlot, 0x60), nextSlot)
    }
}

// Removes a specific installed module
function removeInstalledModule(uint256 index, address account) {
    bytes32 lengthSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleSlot.", keccak256(abi.encodePacked(account)))
    );
    bytes32 headSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleHead.", keccak256(abi.encodePacked(account)))
    );
    bytes32 tailSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleTail.", keccak256(abi.encodePacked(account)))
    );
    assembly {
        // Get the length of the list
        let length := sload(lengthSlot)
        // Get the initial element slot
        let elementSlot := sload(headSlot)
        // Ensure the index is within bounds
        if lt(index, length) {
            // Traverse to the node to remove
            for { let i := 0 } lt(i, index) { i := add(i, 1) } {
                elementSlot := sload(add(elementSlot, 0x60))
            }

            // Get the previous and next slots
            let prevSlot := sload(add(elementSlot, 0x40))
            let nextSlot := sload(add(elementSlot, 0x60))

            // Update the previous slot's next pointer
            sstore(add(prevSlot, 0x60), nextSlot)
            // Update the next slot's previous pointer
            sstore(add(nextSlot, 0x40), prevSlot)

            // Handle removing the head
            if eq(elementSlot, sload(headSlot)) { sstore(headSlot, nextSlot) }

            // Handle removing the tail
            if eq(elementSlot, sload(tailSlot)) { sstore(tailSlot, prevSlot) }

            // Clear the removed node
            sstore(elementSlot, 0)
            sstore(add(elementSlot, 0x20), 0)
            sstore(add(elementSlot, 0x40), 0)
            sstore(add(elementSlot, 0x60), 0)

            // Update the length of the list
            sstore(lengthSlot, sub(length, 1))
        }
    }
}

// Returns all installed modules for the given account
function getInstalledModules(address account) view returns (InstalledModule[] memory modules) {
    bytes32 lengthSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleSlot.", keccak256(abi.encodePacked(account)))
    );
    bytes32 headSlot = keccak256(
        abi.encode("ModuleKit.InstalledModuleHead.", keccak256(abi.encodePacked(account)))
    );
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

        // Get the head of the linked list
        let storageLocation := sload(headSlot)

        // Copy the structs from storage to memory
        for { let i := 0 } lt(i, length) { i := add(i, 1) } {
            // Calculate memory location for this struct
            let structLocation :=
                add(add(freeMemoryPtr, add(0x40, mul(i, structSize))), mul(0x20, length))

            // Load the moduleType and moduleAddress from storage
            let moduleType := sload(storageLocation)
            let moduleAddress := sload(add(storageLocation, 0x20))

            // Store the structLocation into memory
            mstore(add(freeMemoryPtr, add(0x20, mul(i, 0x20))), structLocation)

            // Store the moduleType and moduleAddress into memory
            mstore(structLocation, moduleType)
            mstore(add(structLocation, 0x20), moduleAddress)

            // Move to the next element in the linked list
            storageLocation := sload(add(storageLocation, 0x60))
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
