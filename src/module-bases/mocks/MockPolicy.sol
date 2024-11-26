// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { PackedUserOperation } from
    "@ERC4337/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract MockPolicy {
    mapping(address account => uint256 validation) public validationData;
    mapping(
        bytes32 id => mapping(address msgSender => mapping(address userOpSender => uint256 calls))
    ) public userOpState;
    mapping(
        bytes32 id => mapping(address msgSender => mapping(address userOpSender => uint256 calls))
    ) public actionState;

    function setValidationData(address account, uint256 validation) external {
        validationData[account] = validation;
    }

    function initializeWithMultiplexer(
        address account,
        bytes32 configId,
        bytes calldata
    )
        external
    {
        userOpState[configId][msg.sender][account] = 1;
    }

    function checkUserOpPolicy(
        bytes32 id,
        PackedUserOperation calldata userOp
    )
        external
        returns (uint256)
    {
        userOpState[id][msg.sender][userOp.sender] += 1;
        return validationData[userOp.sender];
    }

    function checkAction(
        bytes32 id,
        address account,
        address,
        uint256,
        bytes calldata
    )
        external
        returns (uint256)
    {
        actionState[id][msg.sender][account] += 1;
        return validationData[account];
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function check1271SignedAction(
        bytes32,
        address,
        address,
        bytes32,
        bytes calldata
    )
        external
        pure
        returns (bool)
    {
        return true;
    }
}
