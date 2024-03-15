// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    CFASuperAppBase,
    ISuperfluid,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";

import { SuperTokenV1Library } from
    "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import "forge-std/console2.sol";

contract SuperLicense is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;

    ISuperToken public immutable TOKEN;

    enum Operation {
        NEW,
        UPDATE,
        DELETE
    }

    struct LicenseData {
        Operation operation;
        address module;
        int96 value;
    }

    struct Beneficiary {
        address account;
        uint8 equity;
    }

    mapping(address account => mapping(address module => int96)) internal licenses;

    constructor(ISuperToken _acceptedToken, ISuperfluid host) CFASuperAppBase(host) {
        selfRegister(true, true, true);
        TOKEN = _acceptedToken;
    }

    function onFlowCreated(
        ISuperToken, /*superToken*/
        address sender, /*sender*/
        bytes calldata ctx
    )
        internal
        virtual
        override
        returns (bytes memory /*newCtx*/ )
    {
        int96 senderFlowRate = SuperTokenV1Library.getCFANetFlowRate(TOKEN, sender);
        ISuperfluid.Context memory context = HOST.decodeCtx(ctx);
        console2.log("onFlowCreated");
        console2.log("sender: %s senderContext %s, ", sender, context.msgSender);
        console2.log(senderFlowRate);
        console2.logBytes(context.userData);
        int256 value;
        LicenseData[] memory licenseDatas = abi.decode(context.userData, (LicenseData[]));
        for (uint256 i; i < licenseDatas.length; i++) {
            console2.log("licenseData: %s", uint8(licenseDatas[i].operation));
            console2.log("licenseData: %s", licenseDatas[i].module);
        }
        return ctx;
    }

    /// @dev override if the SuperApp shall have custom logic invoked when an existing flow
    ///      to it is updated (flowrate change).
    function onFlowUpdated(
        ISuperToken, /*superToken*/
        address, /*sender*/
        int96, /*previousFlowRate*/
        uint256, /*lastUpdated*/
        bytes calldata ctx
    )
        internal
        virtual
        override
        returns (bytes memory /*newCtx*/ )
    {
        return ctx;
    }

    /// @dev override if the SuperApp shall have custom logic invoked when an existing flow
    ///      to it is deleted (flowrate set to 0).
    ///      Unlike the other callbacks, this method is NOT allowed to revert.
    ///      Failing to satisfy that requirement leads to jailing (defunct SuperApp).
    function onFlowDeleted(
        ISuperToken, /*superToken*/
        address, /*sender*/
        address, /*receiver*/
        int96, /*previousFlowRate*/
        uint256, /*lastUpdated*/
        bytes calldata ctx
    )
        internal
        virtual
        override
        returns (bytes memory /*newCtx*/ )
    {
        return ctx;
    }
}
