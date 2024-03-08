// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/SafeERC7579.sol";
import "src/SafeERC7579.sol";
import "src/utils/Launchpad.sol";
import "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import "@safe-global/safe-contracts/contracts/Safe.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "@rhinestone/modulekit/src/test/predeploy/EntryPoint.sol";

import { EntryPoint } from "@ERC4337/account-abstraction/contracts/core/EntryPoint.sol";

import { LibClone } from "solady/src/utils/LibClone.sol";

contract SafeLaunchPadTest is Test {
    SafeERC7579 safe7579;
    Safe singleton;
    Safe safeAccount;
    SafeProxyFactory safeProxyFactory;
    Launchpad launchpad;

    MockValidator defaultValidator;

    Account signer1 = makeAccount("signer1");
    Account signer2 = makeAccount("signer2");

    IEntryPoint entrypoint;

    function setUp() public {
        singleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        launchpad = new Launchpad();
        safe7579 = new SafeERC7579();

        entrypoint = etchEntrypoint();

        defaultValidator = new MockValidator();

        address[] memory validators = new address[](1);
        validators[0] = address(defaultValidator);
        bytes[] memory validatorsInitCode = new bytes[](1);

        bytes memory safeLaunchPadSetup = abi.encodeCall(
            Launchpad.initSafe7579,
            (
                address(safe7579),
                abi.encode(validators, validatorsInitCode, new address[](0), new bytes[](0))
            )
        );

        address[] memory owners = new address[](2);
        owners[0] = signer1.addr;
        owners[1] = signer2.addr;
        // SETUP SAFE
        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (
                owners,
                2,
                address(launchpad),
                safeLaunchPadSetup,
                address(safe7579),
                address(0),
                0,
                payable(address(0))
            )
        );
        uint256 salt = 0;

        // SafeProxy safeProxy =
        //     safeProxyFactory.createProxyWithNonce(address(singleton), initializer, salt);
    }

    function test_createAccount() public {
        address[] memory validators = new address[](1);
        validators[0] = address(defaultValidator);
        bytes[] memory validatorsInitCode = new bytes[](1);

        bytes memory safeLaunchPadSetup = abi.encodeCall(
            Launchpad.initSafe7579,
            (
                address(safe7579),
                abi.encode(validators, validatorsInitCode, new address[](0), new bytes[](0))
            )
        );

        address[] memory owners = new address[](2);
        owners[0] = signer1.addr;
        owners[1] = signer2.addr;
        // SETUP SAFE
        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (
                owners,
                2,
                address(launchpad),
                safeLaunchPadSetup,
                address(safe7579),
                address(0),
                0,
                payable(address(0))
            )
        );
        uint256 salt = 0;

        address account = _predictAddress(bytes32(salt), initializer);
        vm.deal(account, 1 ether);
        PackedUserOperation memory userOp = getDefaultUserOp(account);
        userOp.initCode = abi.encodePacked(
            address(safeProxyFactory),
            abi.encodeCall(
                SafeProxyFactory.createProxyWithNonce, (address(singleton), initializer, salt)
            )
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function getDefaultUserOp(address account)
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: account,
            nonce: safe7579.getNonce(address(account), address(defaultValidator)),
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }

    function _predictAddress(
        bytes32 salt,
        bytes memory initializer
    )
        internal
        returns (address safeProxy)
    {
        bytes memory deploymentData = abi.encodePacked(
            safeProxyFactory.proxyCreationCode(), uint256(uint160(address(singleton)))
        );
        bytes32 hash = LibClone.initCodeHash(address(singleton));
        safeProxy = LibClone.predictDeterministicAddress(hash, salt, address(safeProxyFactory));
        salt = keccak256(abi.encodePacked(keccak256(initializer), salt));

        safeProxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(safeProxyFactory),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    safeProxyFactory.proxyCreationCode(),
                                    uint256(uint160(address(singleton)))
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    function test_foo() public { }
}
