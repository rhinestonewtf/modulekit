// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager
} from "../../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
/* solhint-disable no-global-import */
import "./Vm.sol";
import "./Log.sol";
import "./GasCalculations.sol";
import "forge-std/console2.sol";

library ERC4337Helpers {
    error UserOperationReverted(
        bytes32 userOpHash, address sender, uint256 nonce, bytes revertReason
    );

    function exec4337(PackedUserOperation[] memory userOps, IEntryPoint onEntryPoint) internal {
        // ERC-4337 specs validation
        if (envOr("SIMULATE", false) || getSimulateUserOp()) {
            simulateUserOps(userOps, onEntryPoint);
        }
        // Record logs to determine if a revert happened
        recordLogs();

        // Execute userOps
        address beneficiary = address(0x69);
        onEntryPoint.handleOps(userOps, payable(beneficiary));

        // Parse logs and determine if a revert happened
        VmSafe.Log[] memory logs = getRecordedLogs();
        uint256 isExpectRevert = getExpectRevert();
        uint256 totalUserOpGas = 0;
        for (uint256 i; i < logs.length; i++) {
            // UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)
            if (
                logs[i].topics[0]
                    == 0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f
            ) {
                (uint256 nonce, bool success,, uint256 actualGasUsed) =
                    abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
                totalUserOpGas = actualGasUsed;
                if (!success) {
                    if (isExpectRevert == 0) {
                        bytes32 userOpHash = logs[i].topics[1];
                        bytes memory revertReason = getUserOpRevertReason(logs, userOpHash);
                        revert UserOperationReverted(
                            userOpHash, address(bytes20(logs[i].topics[2])), nonce, revertReason
                        );
                    } else {
                        writeExpectRevert(0);
                    }
                }
            }
        }
        isExpectRevert = getExpectRevert();
        if (isExpectRevert != 0) revert("UserOperation did not revert");
        writeExpectRevert(0);

        // Calculate gas for userOp
        string memory gasIdentifier = getGasIdentifier();
        if (
            envOr("GAS", false) && bytes(gasIdentifier).length > 0
                && bytes(gasIdentifier).length < 50
        ) {
            calculateGas(userOps, onEntryPoint, beneficiary, gasIdentifier, totalUserOpGas);
        }

        for (uint256 i; i < userOps.length; i++) {
            emit ModuleKitLogs.ModuleKit_Exec4337(userOps[i].sender);
        }
    }

    function exec4337(PackedUserOperation memory userOp, IEntryPoint onEntryPoint) internal {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        exec4337(userOps, onEntryPoint);
    }

    function simulateUserOps(
        PackedUserOperation[] memory userOps,
        IEntryPoint onEntryPoint
    )
        internal
    {
        uint256 snapShotId = snapshot();
        IEntryPointSimulations simulationEntryPoint = IEntryPointSimulations(address(onEntryPoint));
        for (uint256 i; i < userOps.length; i++) {
            PackedUserOperation memory userOp = userOps[i];
            startMappingRecording();
            startStateDiffRecording();
            IEntryPointSimulations.ValidationResult memory result =
                simulationEntryPoint.simulateValidation(userOp);
            VmSafe.AccountAccess[] memory accesses = stopAndReturnStateDiff();
            ERC4337SpecsParser.parseValidation(accesses, userOp);
            stopMappingRecording();
        }
        revertTo(snapShotId);
    }

    function getUserOpRevertReason(
        VmSafe.Log[] memory logs,
        bytes32 userOpHash
    )
        internal
        returns (bytes memory revertReason)
    {
        for (uint256 i; i < logs.length; i++) {
            // UserOperationRevertReason(bytes32,address,uint256,bytes)
            if (
                logs[i].topics[0]
                    == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
            ) {
                (, revertReason) = abi.decode(logs[i].data, (uint256, bytes));
            }
        }
    }

    function calculateGas(
        PackedUserOperation[] memory userOps,
        IEntryPoint onEntryPoint,
        address beneficiary,
        string memory gasIdentifier,
        uint256 totalUserOpGas
    )
        internal
    {
        bytes memory userOpCalldata =
            abi.encodeWithSelector(onEntryPoint.handleOps.selector, userOps, beneficiary);
        GasParser.parseAndWriteGas(
            userOpCalldata, address(onEntryPoint), gasIdentifier, userOps[0].sender, totalUserOpGas
        );
    }

    function map(
        PackedUserOperation[] memory self,
        function(PackedUserOperation memory) returns (PackedUserOperation memory) f
    )
        internal
        returns (PackedUserOperation[] memory)
    {
        PackedUserOperation[] memory result = new PackedUserOperation[](self.length);
        for (uint256 i; i < self.length; i++) {
            result[i] = f(self[i]);
        }
        return result;
    }

    function map(
        PackedUserOperation memory self,
        function(PackedUserOperation memory) internal  returns (PackedUserOperation memory) fn
    )
        internal
        returns (PackedUserOperation memory)
    {
        return fn(self);
    }

    function reduce(
        PackedUserOperation[] memory self,
        function(PackedUserOperation memory, PackedUserOperation memory)  returns (PackedUserOperation memory)
            f
    )
        internal
        returns (PackedUserOperation memory r)
    {
        r = self[0];
        for (uint256 i = 1; i < self.length; i++) {
            r = f(r, self[i]);
        }
    }

    function array(PackedUserOperation memory op)
        internal
        pure
        returns (PackedUserOperation[] memory ops)
    {
        ops = new PackedUserOperation[](1);
        ops[0] = op;
    }

    function array(
        PackedUserOperation memory op1,
        PackedUserOperation memory op2
    )
        internal
        pure
        returns (PackedUserOperation[] memory ops)
    {
        ops = new PackedUserOperation[](2);
        ops[0] = op1;
        ops[0] = op2;
    }
}

library ERC4337SpecsParser {
    error InvalidStorageLocation(
        address contractAddress,
        string contractLabel,
        bytes32 slot,
        bytes32 previousValue,
        bytes32 newValue,
        bool isWrite
    );
    error InvalidOpcode(address contractAddress, string opcode);

    function parseValidation(
        VmSafe.AccountAccess[] memory accesses,
        PackedUserOperation memory userOp
    )
        internal
    {
        validateBannedOpcodes();
        for (uint256 i; i < accesses.length; i++) {
            VmSafe.AccountAccess memory currentAccess = accesses[i];
            if (currentAccess.account != address(this) && currentAccess.accessor != address(this)) {
                validateBannedStorageLocations(correctBug(accesses, i), userOp);
                validateDisallowedCalls(currentAccess, userOp);
                validateDisallowedExtOpCodes(currentAccess);
                validateDisallowedCreate(currentAccess, userOp);
            }
        }
    }

    function validateBannedOpcodes() internal pure {
        // todo
        // forbidden opcodes are GASPRICE, GASLIMIT, DIFFICULTY, TIMESTAMP, BASEFEE, BLOCKHASH,
        // NUMBER, SELFBALANCE, BALANCE, ORIGIN, GAS, CREATE, COINBASE, SELFDESTRUCT
        // Exception: GAS is allowed if followed immediately by one of { CALL, DELEGATECALL,
        // CALLCODE, STATICCALL }]
        // revert InvalidOpcode(currentAccess.account, opcode);
    }

    function validateBannedStorageLocations(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
    )
        internal
    {
        address currentAccessAccount = currentAccess.account;

        // todo: deal with accesskind resume

        if (currentAccessAccount != userOp.sender && !isStaked(currentAccessAccount)) {
            for (uint256 j; j < currentAccess.storageAccesses.length; j++) {
                bytes32 currentSlot = currentAccess.storageAccesses[j].slot;
                if (currentSlot != bytes32(bytes20(userOp.sender))) {
                    // this hack is needed until access kind resume is properly dealt with (this is
                    // related to the delegatecall bug)
                    string memory bootstrap = "ERC7579Bootstrap";
                    string memory _label = getLabel(currentAccessAccount);
                    if (keccak256(bytes(_label)) != keccak256(bytes(bootstrap))) {
                        (bool found, bytes32 key) =
                            getMappingParent(currentAccessAccount, currentSlot);
                        if (found) {
                            address parentSlotAddress = address(uint160(uint256(key)));
                            if (parentSlotAddress != userOp.sender) {
                                revert InvalidStorageLocation(
                                    currentAccessAccount,
                                    getLabel(currentAccessAccount),
                                    currentSlot,
                                    currentAccess.storageAccesses[j].previousValue,
                                    currentAccess.storageAccesses[j].newValue,
                                    currentAccess.storageAccesses[j].isWrite
                                );
                            }
                        } else {
                            revert InvalidStorageLocation(
                                currentAccessAccount,
                                getLabel(currentAccessAccount),
                                currentSlot,
                                currentAccess.storageAccesses[j].previousValue,
                                currentAccess.storageAccesses[j].newValue,
                                currentAccess.storageAccesses[j].isWrite
                            );
                        }
                    }
                }
            }
        }
    }

    function validateDisallowedCalls(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
    )
        internal
        view
    {
        if (
            currentAccess.kind == VmSafe.AccountAccessKind.Call
                || currentAccess.kind == VmSafe.AccountAccessKind.DelegateCall
                || currentAccess.kind == VmSafe.AccountAccessKind.CallCode
                || currentAccess.kind == VmSafe.AccountAccessKind.StaticCall
        ) {
            if (
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
            ) {
                revert("Cannot call addresses without code");
            }

            bool callerIsAccount = currentAccess.accessor == userOp.sender;
            bool calleeIsEntryPoint = currentAccess.account == ENTRYPOINT_ADDR;

            if (currentAccess.value > 0) {
                if (!callerIsAccount || !calleeIsEntryPoint) {
                    revert("Cannot use value except from account to EntryPoint");
                }
            }

            if (calleeIsEntryPoint) {
                if (
                    currentAccess.data.length > 4
                        && bytes4(currentAccess.data) != bytes4(0xb760faf9)
                ) {
                    if (currentAccess.accessor != ENTRYPOINT_ADDR) {
                        revert("Cannot call EntryPoint except depositTo");
                    }
                }
            }
        }
    }

    function validateDisallowedExtOpCodes(VmSafe.AccountAccess memory currentAccess)
        internal
        view
    {
        if (
            currentAccess.kind == VmSafe.AccountAccessKind.Extcodesize
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodehash
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodecopy
        ) {
            if (
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
            ) {
                revert("EXT* opcodes cannot access addresses without code");
            }
        }
    }

    function validateDisallowedCreate(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
    )
        internal
        pure
    {
        if (currentAccess.kind == VmSafe.AccountAccessKind.Create) {
            if (userOp.initCode.length == 0 || currentAccess.account != userOp.sender) {
                revert(
                    "Only one CREATE2 opcode is allowed in a user operation, to deploy the account"
                );
            }
        }
    }

    // This is currently a bug in foundry, see https://github.com/foundry-rs/foundry/issues/7006
    // This function compensates for the bug
    function correctBug(
        VmSafe.AccountAccess[] memory accesses,
        uint256 currentIndex
    )
        internal
        view
        returns (VmSafe.AccountAccess memory currentAccess)
    {
        currentAccess = accesses[currentIndex];
        if (currentAccess.kind == VmSafe.AccountAccessKind.DelegateCall) {
            for (uint256 k = 1; k < currentIndex; k++) {
                if (accesses[currentIndex - k].kind == VmSafe.AccountAccessKind.Call) {
                    currentAccess.account = accesses[currentIndex - k].account;
                    break;
                }
            }
        }
    }

    function getMappingParent(
        address currentAccessAccount,
        bytes32 currentSlot
    )
        internal
        returns (bool found, bytes32 key)
    {
        (bool _found, bytes32 _key,) = getMappingKeyAndParentOf(currentAccessAccount, currentSlot);
        if (_found) {
            found = _found;
            key = _key;
        } else {
            for (uint256 k = 1; k <= 128; k++) {
                (_found, _key,) = getMappingKeyAndParentOf(
                    currentAccessAccount, bytes32(uint256(currentSlot) - k)
                );
                if (_found) {
                    found = _found;
                    key = _key;
                    break;
                }
            }
        }
    }

    function isStaked(address entity) internal view returns (bool) {
        IStakeManager.DepositInfo memory deposit =
            IStakeManager(ENTRYPOINT_ADDR).getDepositInfo(entity);
        return deposit.stake > 0;
    }
}

library GasParser {
    function parseAndWriteGas(
        bytes memory userOpCalldata,
        address entrypoint,
        string memory gasIdentifier,
        address sender,
        uint256 totalUserOpGas
    )
        internal
    {
        string memory fileName = string.concat("./gas_calculations/", gasIdentifier, ".json");

        GasCalculations memory gasCalculations = GasCalculations({
            creation: GasDebug(entrypoint).getGasConsumed(sender, 0),
            validation: GasDebug(entrypoint).getGasConsumed(sender, 1),
            execution: GasDebug(entrypoint).getGasConsumed(sender, 2),
            total: totalUserOpGas,
            arbitrum: getArbitrumL1Gas(userOpCalldata),
            opStack: getOpStackL1Gas(userOpCalldata)
        });

        GasCalculations memory prevGasCalculations;

        if (exists(fileName)) {
            string memory fileContent = readFile(fileName);
            prevGasCalculations = parsePrevGasReport(fileContent);
        }

        string memory finalJson =
            formatGasToWrite(gasIdentifier, prevGasCalculations, gasCalculations);

        writeJson(finalJson, fileName);
        writeGasIdentifier("");
    }

    function formatGasToWrite(
        string memory gasIdentifier,
        GasCalculations memory prevGasCalculations,
        GasCalculations memory gasCalculations
    )
        internal
        returns (string memory finalJson)
    {
        string memory jsonObj = string(abi.encodePacked(gasIdentifier));

        // total gas used
        serializeString(
            jsonObj,
            "Total",
            formatGasValue({ prevValue: prevGasCalculations.total, newValue: gasCalculations.total })
        );

        // ERC-4337 phases gas used
        string memory phasesObj = "phases";
        serializeString(
            phasesObj,
            "Creation",
            formatGasValue({
                prevValue: prevGasCalculations.creation,
                newValue: gasCalculations.creation
            })
        );
        serializeString(
            phasesObj,
            "Validation",
            formatGasValue({
                prevValue: prevGasCalculations.validation,
                newValue: gasCalculations.validation
            })
        );
        string memory phasesOutput = serializeString(
            phasesObj,
            "Execution",
            formatGasValue({
                prevValue: prevGasCalculations.execution,
                newValue: gasCalculations.execution
            })
        );

        // L2-L1 calldata gas used
        string memory l2sObj = "l2s";
        serializeString(
            l2sObj,
            "OP-Stack",
            formatGasValue({
                prevValue: prevGasCalculations.opStack,
                newValue: gasCalculations.opStack
            })
        );
        string memory l2sOutput = serializeString(
            l2sObj,
            "Arbitrum",
            formatGasValue({
                prevValue: prevGasCalculations.arbitrum,
                newValue: gasCalculations.arbitrum
            })
        );

        serializeString(jsonObj, "Phases", phasesOutput);
        finalJson = serializeString(jsonObj, "Calldata", l2sOutput);
    }
}
