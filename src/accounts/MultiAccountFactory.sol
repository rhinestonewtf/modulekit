// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SafeFactory } from "./safe/SafeFactory.sol";
import { ERC7579Factory } from "./erc7579/ERC7579Factory.sol";
import { KernelFactory } from "./kernel/KernelFactory.sol";
import { AccountType } from "./MultiAccountHelpers.sol";
import { envOr } from "src/test/utils/Vm.sol";

enum AccountType {
    DEFAULT,
    SAFE,
    KERNEL,
    CUSTOM
}

string constant DEFAULT = "DEFAULT";
string constant SAFE = "SAFE";
string constant KERNEL = "KERNEL";

address constant MULTI_ACCOUNT_FACTORY_ADDRESS = 0x864B12d347dafD27Ce36eD763a3D6764F182F835;

contract MultiAccountFactory is SafeFactory, ERC7579Factory, KernelFactory {
    AccountType public env;

    error InvalidAccountType();

    function init() external {
        string memory _env = envOr("ACCOUNT_TYPE", DEFAULT);

        if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(DEFAULT))) {
            env = AccountType.DEFAULT;
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(SAFE))) {
            env = AccountType.SAFE;
        } else if (keccak256(abi.encodePacked(_env)) == keccak256(abi.encodePacked(KERNEL))) {
            env = AccountType.KERNEL;
        } else {
            revert InvalidAccountType();
        }

        initSafe();
        initERC7579();
        initKernel();
    }

    function createAccount(
        bytes32 salt,
        bytes calldata initCode
    )
        public
        returns (address account)
    {
        if (env == AccountType.SAFE) {
            return createSafe(salt, initCode);
        } else if (env == AccountType.KERNEL) {
            return createKernel(initCode, salt);
        } else {
            return createERC7579(salt, initCode);
        }
    }

    function getAddress(bytes32 salt, bytes memory initCode) public view returns (address) {
        if (env == AccountType.SAFE) {
            return getAddressSafe(salt, initCode);
        } else if (env == AccountType.KERNEL) {
            return getAddressKernel(initCode, salt);
        } else {
            return getAddressERC7579(salt, initCode);
        }
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        external
        view
        returns (bytes memory data)
    {
        if (env == AccountType.SAFE) {
            data = getInitDataSafe(validator, initData);
        } else if (env == AccountType.KERNEL) {
            data = getInitDataKernel(validator, initData);
        } else {
            data = getInitDataERC7579(validator, initData);
        }
    }

    function setAccountType(AccountType _env) public {
        env = _env;
    }

    function getAccountType() public view returns (AccountType) {
        return env;
    }
}
