// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Constants
import { MODULE_TYPE_VALIDATOR } from "src/external/ERC7579.sol";

// Libraries
import { ModuleKitHelpers, AccountInstance } from "src/ModuleKit.sol";

// Mocks
import { MockPolicy, MockTarget } from "src/Mocks.sol";

// Tests
import { BaseTest } from "../BaseTest.t.sol";

// Types
import {
    PermissionId,
    PolicyData,
    ActionData,
    ERC7739Data
} from "src/test/helpers/interfaces/ISmartSession.sol";

/// @dev Tests for smart session integration within the RhinestoneModuleKit
contract SmartSessionTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for AccountInstance;

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
        assertTrue(instance.isSessionEnabled(permissionIds[0]));
    }

    function test_addSession_preInstalled() public {
        // Install a module
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
        assertTrue(instance.isSessionEnabled(permissionIds[0]));
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
        assertTrue(instance.isSessionEnabled(permissionIds[0]));
        // Remove the session
        instance.removeSession(permissionIds[0]);
        // Check if the session is disabled
        assertFalse(instance.isSessionEnabled(permissionIds[0]));
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
        returns (ERC7739Data memory)
    {
        string[] memory contents = new string[](1);
        contents[0] = content;
        return ERC7739Data({ allowedERC7739Content: contents, erc1271Policies: erc1271Policies });
    }
}
