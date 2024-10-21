// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Constants
import { MODULE_TYPE_VALIDATOR } from "src/external/ERC7579.sol";

// Libraries
import { ModuleKitHelpers, AccountInstance } from "src/ModuleKit.sol";
import { ecdsaSign } from "src/Helpers.sol";

// Mocks
import { MockPolicy, MockTarget } from "src/Mocks.sol";
import { MockK1Validator } from "test/mocks/MockK1Validator.sol";

// Tests
import { BaseTest } from "../BaseTest.t.sol";

// Types
import {
    PermissionId,
    PolicyData,
    ActionData,
    ERC7739Data,
    Session,
    ISessionValidator
} from "src/test/helpers/interfaces/ISmartSession.sol";
import { UserOpData, PackedUserOperation } from "src/test/RhinestoneModuleKit.sol";

/// @dev Tests for smart session integration within the RhinestoneModuleKit
contract SmartSessionTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for AccountInstance;
    using ModuleKitHelpers for UserOpData;

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    // @dev A policy contract that allows any action
    MockPolicy mockPolicy;
    // @@dev A mock target contract
    MockTarget target;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        // Deploy mock policy
        mockPolicy = new MockPolicy();
        // Set the policy to allow any action
        mockPolicy.setValidationData(0);
        // Deploy mock target
        target = new MockTarget();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isModuleType() public view {
        // Check if the module type is correct
        assertTrue(
            auxiliary.smartSession.isModuleType(1) //  ERC7579_MODULE_TYPE_VALIDATOR;
        );
    }

    function test_installModule() public {
        // Check if the module is not installed
        assertFalse(
            instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, address(auxiliary.smartSession))
        );
        // Install a module
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(auxiliary.smartSession),
            data: ""
        });
        // Check if the module is installed
        assertTrue(
            instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, address(auxiliary.smartSession))
        );
    }

    function test_addSession() public {
        // Add a session
        PermissionId[] memory permissionIds = instance.addSession({
            salt: bytes32("salt1"),
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policy: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actionDatas: _getEmptyActionDatas(
                address(target), MockTarget.set.selector, address(mockPolicy)
            )
        });
        // Check if the session is enabled
        assertTrue(instance.isPermissionEnabled(permissionIds[0]));
    }

    function test_addSession_preInstalled() public {
        // Install smart session
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(auxiliary.smartSession),
            data: ""
        });
        // Add a session
        PermissionId[] memory permissionIds = instance.addSession({
            salt: bytes32("salt1"),
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policy: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actionDatas: _getEmptyActionDatas(
                address(target), MockTarget.set.selector, address(mockPolicy)
            )
        });
        // Check if the session is enabled
        assertTrue(instance.isPermissionEnabled(permissionIds[0]));
    }

    function test_removeSession() public {
        // Add a session
        PermissionId[] memory permissionIds = instance.addSession({
            salt: bytes32("salt1"),
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policy: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actionDatas: _getEmptyActionDatas(
                address(target), MockTarget.set.selector, address(mockPolicy)
            )
        });
        // Check if the session is enabled
        assertTrue(instance.isPermissionEnabled(permissionIds[0]));
        // Remove the session
        instance.removeSession(permissionIds[0]);
        // Check if the session is disabled
        assertFalse(instance.isPermissionEnabled(permissionIds[0]));
    }

    function test_getPermissionId() public {
        // Setup session data
        Session memory session = Session({
            sessionValidator: ISessionValidator(address(instance.defaultSessionValidator)),
            salt: "mockSalt",
            sessionValidatorInitData: "mockInitData",
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policies: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actions: _getEmptyActionDatas(address(target), MockTarget.set.selector, address(mockPolicy))
        });

        // Add a session
        PermissionId[] memory permissionIds = instance.addSession({ session: session });
        // Get the permission id
        PermissionId permissionId = instance.getPermissionId(session);

        // Check if the permission id is correct
        assertTrue(permissionIds[0] == permissionId);
    }

    function test_useSession() public {
        // Setup calldata to execute
        bytes memory callData = abi.encodeWithSelector(MockTarget.set.selector, (1337));

        // Setup session data
        Session memory session = Session({
            sessionValidator: ISessionValidator(address(instance.defaultSessionValidator)),
            salt: "mockSalt",
            sessionValidatorInitData: "mockInitData",
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policies: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actions: _getEmptyActionDatas(address(target), MockTarget.set.selector, address(mockPolicy))
        });

        // Use the session
        instance.useSession(session, address(target), 0, /* value */ callData);

        // Check if the value was set
        assertTrue(target.value() == 1337);
    }

    function test_encodeSignatureEnableMode() public {
        // Deploy MockK1Validator
        MockK1Validator mockK1Validator = new MockK1Validator();

        // Make an owner
        Account memory owner = makeAccount("owner");

        // Install validator
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mockK1Validator),
            data: abi.encodePacked(owner.addr)
        });

        // Install smart session
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(auxiliary.smartSession),
            data: ""
        });

        // Setup calldata to execute
        bytes memory callData = abi.encodeWithSelector(MockTarget.set.selector, (1337));

        // Get exec user ops
        UserOpData memory userOpData = instance.getExecOps({
            target: address(target),
            value: 0,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        });

        // Setup session data
        Session memory session = Session({
            sessionValidator: ISessionValidator(address(instance.defaultSessionValidator)),
            salt: "mockSalt",
            sessionValidatorInitData: "mockInitData",
            userOpPolicies: _getEmptyPolicyDatas(address(mockPolicy)),
            erc7739Policies: _getEmptyERC7739Data(
                "mockContent", _getEmptyPolicyDatas(address(mockPolicy))
            ),
            actions: _getEmptyActionDatas(address(target), MockTarget.set.selector, address(mockPolicy))
        });

        // Get enable mode signature
        bytes memory signature = instance.encodeSignatureEnableMode(
            userOpData.userOp, session, ecdsaSign, address(mockK1Validator), owner.key
        );

        // Update the user op signature
        userOpData.userOp.signature = signature;

        // Execute user ops
        userOpData.execUserOps();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getEmptyPolicyDatas(address policyContract)
        internal
        pure
        returns (PolicyData[] memory policyDatas)
    {
        policyDatas = new PolicyData[](1);
        policyDatas[0] = _getEmptyPolicyData(policyContract);
    }

    function _getEmptyPolicyData(address policyContract)
        internal
        pure
        returns (PolicyData memory)
    {
        return PolicyData({ policy: policyContract, initData: "" });
    }

    function _getEmptyActionData(
        address actionTarget,
        bytes4 actionSelector,
        address policyContract
    )
        internal
        pure
        returns (ActionData memory)
    {
        return ActionData({
            actionTargetSelector: actionSelector,
            actionTarget: actionTarget,
            actionPolicies: _getEmptyPolicyDatas(policyContract)
        });
    }

    function _getEmptyActionDatas(
        address actionTarget,
        bytes4 actionSelector,
        address policyContract
    )
        internal
        pure
        returns (ActionData[] memory actionDatas)
    {
        actionDatas = new ActionData[](1);
        actionDatas[0] = _getEmptyActionData(actionTarget, actionSelector, policyContract);
    }

    function _getEmptyERC7739Data(
        string memory content,
        PolicyData[] memory erc1271Policies
    )
        internal
        pure
        returns (ERC7739Data memory)
    {
        string[] memory contents = new string[](1);
        contents[0] = content;
        return ERC7739Data({ allowedERC7739Content: contents, erc1271Policies: erc1271Policies });
    }
}
