// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

/// @dev A collection of smart session related libraries, vendored from
/// https://github.com/erc7579/smartsessions

// Interfaces
import {
    SmartSessionMode,
    PermissionId,
    EnableSession,
    ChainDigest,
    Session,
    PolicyData,
    ActionData,
    ERC7739Data
} from "../../integrations/interfaces/ISmartSession.sol";

// Libraries
import { LibZip } from "solady/utils/LibZip.sol";
import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Types
import { ModeCode as ExecutionMode } from "../../accounts/common/lib/ModeLib.sol";

library SmartSessionModeLib {
    function isUseMode(SmartSessionMode mode) internal pure returns (bool) {
        return mode == SmartSessionMode.USE;
    }

    function isEnableMode(SmartSessionMode mode) internal pure returns (bool) {
        return (mode == SmartSessionMode.ENABLE || mode == SmartSessionMode.UNSAFE_ENABLE);
    }

    function useRegistry(SmartSessionMode mode) internal pure returns (bool) {
        return (mode == SmartSessionMode.ENABLE);
    }
}

library EncodeLib {
    using LibZip for bytes;
    using EncodeLib for *;
    using SmartSessionModeLib for SmartSessionMode;

    error ChainIdAndHashesLengthMismatch(uint256 chainIdsLength, uint256 hashesLength);

    function unpackMode(bytes calldata packed)
        internal
        pure
        returns (SmartSessionMode mode, PermissionId permissionId, bytes calldata data)
    {
        mode = SmartSessionMode(uint8(bytes1(packed[:1])));
        if (mode.isEnableMode()) {
            data = packed[1:];
        } else {
            permissionId = PermissionId.wrap(bytes32(packed[1:33]));
            data = packed[33:];
        }
    }

    function encodeUse(
        PermissionId permissionId,
        bytes memory sig
    )
        internal
        pure
        returns (bytes memory userOpSig)
    {
        userOpSig =
            abi.encodePacked(SmartSessionMode.USE, permissionId, abi.encode(sig).flzCompress());
    }

    function decodeUse(bytes memory packedSig) internal pure returns (bytes memory signature) {
        (signature) = abi.decode(packedSig.flzDecompress(), (bytes));
    }

    function encodeUnsafeEnable(
        bytes memory sig,
        EnableSession memory enableData
    )
        internal
        pure
        returns (bytes memory packedSig)
    {
        packedSig = abi.encodePacked(
            SmartSessionMode.UNSAFE_ENABLE, abi.encode(enableData, sig).flzCompress()
        );
    }

    function encodeEnable(
        bytes memory sig,
        EnableSession memory enableData
    )
        internal
        pure
        returns (bytes memory packedSig)
    {
        packedSig =
            abi.encodePacked(SmartSessionMode.ENABLE, abi.encode(enableData, sig).flzCompress());
    }

    function decodeEnable(bytes calldata packedSig)
        internal
        pure
        returns (EnableSession memory enableData, bytes memory signature)
    {
        (enableData, signature) = abi.decode(packedSig.flzDecompress(), (EnableSession, bytes));
    }
}

// Typehashes
string constant POLICY_DATA_NOTATION = "PolicyData(address policy,bytes initData)";
string constant ACTION_DATA_NOTATION =
    "ActionData(address actionTarget, bytes4 actionTargetSelector,PolicyData[] actionPolicies)";
string constant ERC7739_DATA_NOTATION =
    "ERC7739Data(string[] allowedERC7739Content,PolicyData[] erc1271Policies)";

bytes32 constant POLICY_DATA_TYPEHASH = keccak256(bytes(POLICY_DATA_NOTATION));
bytes32 constant ACTION_DATA_TYPEHASH = keccak256(bytes(ACTION_DATA_NOTATION));
bytes32 constant ERC7739_DATA_TYPEHASH = keccak256(bytes(ERC7739_DATA_NOTATION));

string constant SESSION_NOTATION =
    "Session(address account,address smartSession,uint8 mode,address sessionValidator,bytes32 salt,bytes sessionValidatorInitData,PolicyData[] userOpPolicies,ERC7739Data erc7739Policies,ActionData[] actions)";
string constant CHAIN_SESSION_NOTATION = "ChainSession(uint64 chainId,Session session)";
string constant MULTI_CHAIN_SESSION_NOTATION =
    "MultiChainSession(ChainSession[] sessionsAndChainIds)";

bytes32 constant SESSION_TYPEHASH = keccak256(
    abi.encodePacked(
        bytes(SESSION_NOTATION),
        bytes(POLICY_DATA_NOTATION),
        bytes(ACTION_DATA_NOTATION),
        bytes(ERC7739_DATA_NOTATION)
    )
);

bytes32 constant CHAIN_SESSION_TYPEHASH = keccak256(
    abi.encodePacked(
        bytes(CHAIN_SESSION_NOTATION),
        bytes(SESSION_NOTATION),
        bytes(POLICY_DATA_NOTATION),
        bytes(ACTION_DATA_NOTATION),
        bytes(ERC7739_DATA_NOTATION)
    )
);

bytes32 constant MULTICHAIN_SESSION_TYPEHASH = keccak256(
    abi.encodePacked(
        bytes(MULTI_CHAIN_SESSION_NOTATION),
        bytes(CHAIN_SESSION_NOTATION),
        bytes(SESSION_NOTATION),
        bytes(POLICY_DATA_NOTATION),
        bytes(ACTION_DATA_NOTATION),
        bytes(ERC7739_DATA_NOTATION)
    )
);

/// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address
/// verifyingContract)")`.
bytes32 constant _DOMAIN_TYPEHASH =
    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

// keccak256(abi.encode(_DOMAIN_TYPEHASH, keccak256("SmartSession"), keccak256(""), 0, address(0)));
// One should use the same domain separator where possible
// or provide the following EIP712Domain struct to the signTypedData() function
// Name: "SmartSession" (string)
// Version: "" (string)
// ChainId: 0 (uint256)
// VerifyingContract: address(0) (address)
// it is introduced for compatibility with signTypedData()
// all the critical data such as chainId and verifyingContract are included
// in session hashes
// https://docs.metamask.io/wallet/reference/eth_signtypeddata_v4
bytes32 constant _DOMAIN_SEPARATOR =
    0xa82dd76056d04dc31e30c73f86aa4966336112e8b5e9924bb194526b08c250c1;

library HashLib {
    error ChainIdMismatch(uint64 providedChainId);
    error HashMismatch(bytes32 providedHash, bytes32 computedHash);

    using EfficientHashLib for bytes32;
    using HashLib for *;

    /**
     * Mimics SignTypedData() behaviour
     * 1. hashStruct(Session)
     * 2. hashStruct(ChainSession)
     * 3. abi.encodePacked hashStruct's for 2) together
     * 4. Hash it together with MULTI_CHAIN_SESSION_TYPEHASH
     * as it was MultiChainSession struct
     * 5. Add multichain domain separator
     * This method doest same, just w/o 1. as it is already provided to us as a digest
     */
    function multichainDigest(ChainDigest[] memory hashesAndChainIds)
        internal
        pure
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(MULTICHAIN_SESSION_TYPEHASH, hashesAndChainIds.hashChainDigestArray())
        );

        return MessageHashUtils.toTypedDataHash(_DOMAIN_SEPARATOR, structHash);
    }

    /**
     * Hash array of ChainDigest structs
     */
    function hashChainDigestArray(ChainDigest[] memory chainDigestArray)
        internal
        pure
        returns (bytes32)
    {
        uint256 length = chainDigestArray.length;
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i; i < length; i++) {
            hashes[i] = chainDigestArray[i].hashChainDigestMimicRPC();
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /**
     * We have session digests, not full Session structs
     * However to mimic signTypedData() behaviour, we need to use CHAIN_SESSION_TYPEHASH
     * not CHAIN_DIGEST_TYPEHASH. We just use the ready session digest instead of rebuilding it
     */
    function hashChainDigestMimicRPC(ChainDigest memory chainDigest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                CHAIN_SESSION_TYPEHASH,
                chainDigest.chainId,
                chainDigest.sessionDigest // this is the digest obtained using sessionDigest()
                    // we just do not rebuild it here for all sessions, but receive it from
                    // off-chain
            )
        );
    }

    /**
     * Hashes the data from the Session struct with some security critical data
     * such as nonce, account address, smart session address, and mode
     */
    function sessionDigest(
        Session memory session,
        address account,
        SmartSessionMode mode,
        uint256 nonce
    )
        internal
        view
        returns (bytes32)
    {
        return _sessionDigest(session, account, address(this), mode, nonce);
    }

    /**
     * Should never be used directly on-chain, only via sessionDigest()
     * Only for external use - to be able to pass smartSession when
     * testing for different chains which may have different addresses for
     * the Smart Session contract
     * It is exactly how signTypedData will hash such an object
     * when this object is an inner struct
     * It won't use eip712 domain for it as it is inner struct
     */
    function _sessionDigest(
        Session memory session,
        address account,
        address smartSession, // for testing purposes
        SmartSessionMode mode,
        uint256 nonce
    )
        internal
        pure
        returns (bytes32 _hash)
    {
        // chainId is not needed as it is in the ChainSession
        _hash = keccak256(
            abi.encode(
                SESSION_TYPEHASH,
                account,
                smartSession,
                uint8(mode), // Include mode as uint8
                address(session.sessionValidator),
                session.salt,
                keccak256(session.sessionValidatorInitData),
                session.userOpPolicies.hashPolicyDataArray(),
                session.erc7739Policies.hashERC7739Data(),
                session.actions.hashActionDataArray(),
                nonce
            )
        );
    }

    function hashPolicyData(PolicyData memory policyData) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(POLICY_DATA_TYPEHASH, policyData.policy, keccak256(policyData.initData))
        );
    }

    function hashPolicyDataArray(PolicyData[] memory policyDataArray)
        internal
        pure
        returns (bytes32)
    {
        uint256 length = policyDataArray.length;
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i; i < length; i++) {
            hashes[i] = policyDataArray[i].hashPolicyData();
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function hashActionData(ActionData memory actionData) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ACTION_DATA_TYPEHASH,
                actionData.actionTargetSelector,
                actionData.actionTarget,
                hashPolicyDataArray(actionData.actionPolicies)
            )
        );
    }

    function hashActionDataArray(ActionData[] memory actionDataArray)
        internal
        pure
        returns (bytes32)
    {
        uint256 length = actionDataArray.length;
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i; i < length; i++) {
            hashes[i] = actionDataArray[i].hashActionData();
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function hashERC7739Data(ERC7739Data memory erc7739Data) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ERC7739_DATA_TYPEHASH,
                erc7739Data.allowedERC7739Content.hashStringArray(),
                erc7739Data.erc1271Policies.hashPolicyDataArray()
            )
        );
    }

    function hashStringArray(string[] memory stringArray) internal pure returns (bytes32) {
        uint256 length = stringArray.length;
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i; i < length; i++) {
            hashes[i] = keccak256(abi.encodePacked(stringArray[i]));
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function hashERC7739Content(string memory content) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(content));
    }

    function getAndVerifyDigest(
        EnableSession memory enableData,
        address account,
        uint256 nonce,
        SmartSessionMode mode
    )
        internal
        view
        returns (bytes32 digest)
    {
        bytes32 computedHash = enableData.sessionToEnable.sessionDigest(account, mode, nonce);

        uint64 providedChainId = enableData.hashesAndChainIds[enableData.chainDigestIndex].chainId;
        bytes32 providedHash =
            enableData.hashesAndChainIds[enableData.chainDigestIndex].sessionDigest;

        if (providedChainId != block.chainid) {
            revert ChainIdMismatch(providedChainId);
        }

        // ensure digest we've built from the sessionToEnable is included into
        // the list of digests that were signed
        if (providedHash != computedHash) {
            revert HashMismatch(providedHash, computedHash);
        }

        digest = enableData.hashesAndChainIds.multichainDigest();
    }
}
