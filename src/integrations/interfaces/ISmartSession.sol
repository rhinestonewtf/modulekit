// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import { IModule } from "../../accounts/common/interfaces/IERC7579Module.sol";

// Types
import { PackedUserOperation } from "../../external/ERC4337.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                 Custom Types & Constants                   */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

type PermissionId is bytes32;

type ActionId is bytes32;

type ValidationData is uint256;

using { permissionIdEq as == } for PermissionId global;
using { permissionIdNeq as != } for PermissionId global;

function permissionIdEq(PermissionId uid1, PermissionId uid2) pure returns (bool) {
    return PermissionId.unwrap(uid1) == PermissionId.unwrap(uid2);
}

function permissionIdNeq(PermissionId uid1, PermissionId uid2) pure returns (bool) {
    return PermissionId.unwrap(uid1) != PermissionId.unwrap(uid2);
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                       Parameters                           */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

enum SmartSessionMode {
    USE,
    ENABLE,
    UNSAFE_ENABLE
}

enum PolicyType {
    NA,
    USER_OP,
    ACTION,
    ERC1271
}

struct EnableSession {
    uint8 chainDigestIndex;
    ChainDigest[] hashesAndChainIds;
    Session sessionToEnable;
    // in order to enable a session, the smart account has to sign a digest. The signature for this
    // is stored here.
    bytes permissionEnableSig;
}

struct ChainDigest {
    uint64 chainId;
    bytes32 sessionDigest;
}

// Action data is a struct that contains the actionId and the policies that are associated with this
// action.
struct ActionData {
    bytes4 actionTargetSelector;
    address actionTarget;
    PolicyData[] actionPolicies;
}

// Policy data is a struct that contains the policy address and the initialization data for the
// policy.
struct PolicyData {
    address policy;
    bytes initData;
}

struct ERC7739Data {
    string[] allowedERC7739Content;
    PolicyData[] erc1271Policies;
}

/**
 *
 * Represents a Session structure with various attributes for managing user operations and policies.
 *
 * Attributes:
 *     sessionValidator (ISessionValidator): The validator contract for signing user operations.
 *         Every userOp must be signed by the session key "owner". The signature is validated
 *         via a stateless external contract (ISessionValidator) that can implement different
 *         means of validation.
 *
 *     sessionValidatorInitData (bytes): Initialization data for the ISessionValidator contract.
 *         The ISessionValidator contract can be configured with different parameters that are
 *         passed in this field.
 *
 *     salt (bytes32): A unique identifier to prevent collision between sessions.
 *         A session key owner can have multiple sessions with the same parameters. To facilitate
 *         this, a salt is necessary to avoid collision.
 *
 *     userOpPolicies (PolicyData[]): An array of policy data for user operations.
 *         When every session can have multiple policies set.
 *
 *     erc7739Policies (ERC7739Data): ERC1271 Policies specific to the ERC7739 standard.
 *
 *     actions (ActionData[]): An array of action data for specifying function-specific policies.
 *         A common use case of session keys is to scope access to a specific target and function
 *         selector. SmartSession calls this "Action". With ActionData, we can specify policies
 *         that are only run if a 7579 execution contains a specific action.
 */
struct Session {
    ISessionValidator sessionValidator;
    bytes sessionValidatorInitData;
    bytes32 salt;
    PolicyData[] userOpPolicies;
    ERC7739Data erc7739Policies;
    ActionData[] actions;
}

/**
 * @title ISmartSession
 * @author Filipp Makarov (Biconomy) & zeroknots.eth (Rhinestone)
 * @dev A collaborative effort between Rhinestone and Biconomy to create a powerful
 *      and flexible session key management system for ERC-4337 and ERC-7579 accounts.
 * SmartSession is an advanced module for ERC-4337 and ERC-7579 compatible smart contract wallets,
 * enabling granular
 * control over session keys. It allows users to create and manage temporary, limited-permission
 * access to their
 * accounts through configurable policies. The module supports various policy types, including user
 * operation
 * validation, action-specific policies, and ERC-1271 signature validation. SmartSession implements
 * a unique "enable
 * flow" that allows session keys to be created within the first user operation, enhancing security
 * and user experience.
 * It uses a nested EIP-712 approach for signature validation, providing phishing resistance and
 * compatibility with
 * existing wallet interfaces. The module also supports batched executions and integrates with
 * external policy contracts
 * for flexible permission management. Overall, SmartSession offers a comprehensive solution for
 * secure, temporary
 * account access in the evolving landscape of account abstraction.
 */
interface ISmartSession {
    error AssociatedArray_OutOfBounds(uint256 index);
    error ChainIdMismatch(uint64 providedChainId);
    error HashIndexOutOfBounds(uint256 index);
    error HashMismatch(bytes32 providedHash, bytes32 computedHash);
    error InvalidData();
    error InvalidActionId();
    error NoExecutionsInBatch();
    error InvalidTarget();
    error InvalidEnableSignature(address account, bytes32 hash);
    error InvalidISessionValidator(ISessionValidator sessionValidator);
    error InvalidSelfCall();
    error InvalidSession(PermissionId permissionId);
    error InvalidSessionKeySignature(
        PermissionId permissionId, address sessionValidator, address account, bytes32 userOpHash
    );
    error SmartSessionModuleAlreadyInstalled(address account);
    error InvalidPermissionId(PermissionId permissionId);
    error InvalidCallTarget();
    error InvalidUserOpSender(address sender);
    error NoPoliciesSet(PermissionId permissionId);
    error PartlyEnabledActions();
    error PartlyEnabledPolicies();
    error PolicyViolation(PermissionId permissionId, address policy);
    error SignerNotFound(PermissionId permissionId, address account);
    error UnsupportedExecutionType();
    error UnsupportedPolicy(address policy);
    error UnsupportedSmartSessionMode(SmartSessionMode mode);
    error ForbiddenValidationData();

    event NonceIterated(PermissionId permissionId, address account, uint256 newValue);
    event SessionValidatorEnabled(
        PermissionId permissionId, address sessionValidator, address smartAccount
    );
    event SessionValidatorDisabled(
        PermissionId permissionId, address sessionValidator, address smartAccount
    );
    event PolicyDisabled(
        PermissionId permissionId, PolicyType policyType, address policy, address smartAccount
    );
    event ActionIdDisabled(PermissionId permissionId, ActionId actionId, address smartAccount);
    event PolicyEnabled(
        PermissionId permissionId, PolicyType policyType, address policy, address smartAccount
    );
    event SessionCreated(PermissionId permissionId, address account);
    event SessionRemoved(PermissionId permissionId, address smartAccount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERC7579                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * ERC4337/ERC7579 validation function
     * the primary purpose of this function, is to validate if a userOp forwarded by a 7579 account
     * is valid.
     * This function will dissect the userop.signature field, and parse out the provided
     * PermissionId, which identifies
     * a
     * unique ID of a dapp for a specific user. n Policies and one Signer contract are mapped to
     * this Id and will be
     * checked. Only UserOps that pass policies and signer checks, are considered valid.
     * Enable Flow:
     *     SmartSessions allows session keys to be created within the "first" UserOp. If the enable
     * flow is chosen, the
     *     EnableSession data, which is packed in userOp.signature is parsed, and stored in the
     * SmartSession storage.
     *
     */
    function validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash
    )
        external
        returns (ValidationData vd);
    /**
     * ERC7579 compliant onInstall function.
     * expected to abi.encode(Session[]) for the enable data
     *
     * Note: It's possible to install the smartsession module with data = ""
     */
    function onInstall(bytes memory data) external;

    /**
     * ERC7579 compliant uninstall function.
     * will wipe all configIds and associated Policies / Signers
     */
    function onUninstall(bytes memory) external;

    /**
     * ERC7579 compliant ERC1271 function
     * this function allows session keys to sign ERC1271 requests.
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes memory signature
    )
        external
        view
        returns (bytes4 result);

    function isInitialized(address smartAccount) external view returns (bool);
    function isModuleType(uint256 typeID) external pure returns (bool);
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Manage Sessions                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function enableActionPolicies(
        PermissionId permissionId,
        ActionData[] memory actionPolicies
    )
        external;
    function enableERC1271Policies(
        PermissionId permissionId,
        ERC7739Data calldata erc1271Policies
    )
        external;
    function enableSessions(Session[] memory sessions)
        external
        returns (PermissionId[] memory permissionIds);
    function enableUserOpPolicies(
        PermissionId permissionId,
        PolicyData[] memory userOpPolicies
    )
        external;
    function disableActionPolicies(
        PermissionId permissionId,
        ActionId actionId,
        address[] memory policies
    )
        external;
    function disableActionId(PermissionId permissionId, ActionId actionId) external;
    function disableERC1271Policies(
        PermissionId permissionId,
        address[] memory policies,
        string[] calldata contents
    )
        external;
    function disableUserOpPolicies(PermissionId permissionId, address[] memory policies) external;
    function removeSession(PermissionId permissionId) external;
    function revokeEnableSignature(PermissionId permissionId) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      View Functions                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getSessionDigest(
        PermissionId permissionId,
        address account,
        Session memory data,
        SmartSessionMode mode
    )
        external
        view
        returns (bytes32);

    function getNonce(PermissionId permissionId, address account) external view returns (uint256);
    function getPermissionId(Session memory session)
        external
        pure
        returns (PermissionId permissionId);
    function isPermissionEnabled(
        PermissionId permissionId,
        address account
    )
        external
        view
        returns (bool);
    function isISessionValidatorSet(
        PermissionId permissionId,
        address account
    )
        external
        view
        returns (bool);
    function areUserOpPoliciesEnabled(
        address account,
        PermissionId permissionId,
        PolicyData[] calldata userOpPolicies
    )
        external
        view
        returns (bool);
    function areERC1271PoliciesEnabled(
        address account,
        PermissionId permissionId,
        PolicyData[] calldata erc1271Policies
    )
        external
        view
        returns (bool);
    function areActionsEnabled(
        address account,
        PermissionId permissionId,
        ActionData[] calldata actions
    )
        external
        view
        returns (bool);
}

/**
 * ISessionValidator is a contract that validates signatures for a given session.
 * this interface expects to validate the signature in a stateless way.
 * all parameters required to validate the signature are passed in the function call.
 * Only one ISessionValidator is responsible to validate a userOp.
 * if you want to use multiple validators, you can create a ISessionValidator that aggregates
 * multiple signatures that
 * are packed into userOp.signature
 * It is used to validate the signature of a session.
 *  hash The userOp hash
 *  sig The signature of userOp
 *  data the config data that is used to validate the signature
 */
interface ISessionValidator is IModule {
    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata sig,
        bytes calldata data
    )
        external
        view
        returns (bool validSig);
}
