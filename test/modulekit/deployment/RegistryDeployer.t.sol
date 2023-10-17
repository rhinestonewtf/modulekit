// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import {
    RegistryDeployer,
    ModuleRecord,
    ResolverRecord
} from "../../../src/modulekit/deployment/RegistryDeployer.sol";
import { MockValidator } from "../../../src/test/mocks/MockValidator.sol";
import { RegistryCode, DebugResolver } from "../../../src/test/utils/dependencies/Registry.sol";

contract MockValidatorFactory {
    function deployModule(uint256 salt) public returns (address proxy) {
        bytes memory deploymentData = abi.encodePacked(type(MockValidator).creationCode);
        assembly {
            proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
    }

    function getModuleAddress(uint256 salt) public view returns (address) {
        bytes memory deploymentData = abi.encodePacked(type(MockValidator).creationCode);
        bytes32 saltBytes = bytes32(salt);
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), saltBytes, keccak256(deploymentData))
        );
        return address(uint160(uint256(hash)));
    }
}

contract RegistryDeployerTest is Test, RegistryDeployer {
    MockValidator mockValidator;
    DebugResolver debugResolver;

    function setUp() public {
        mockValidator = new MockValidator();

        bytes memory args = abi.encode("Test Registry", "0.0.1");

        bytes memory registryBytecode = abi.encodePacked(RegistryCode, args);
        address newRegistry;
        assembly {
            newRegistry := create2(0, add(registryBytecode, 0x20), mload(registryBytecode), 0)
        }
        setRegistry(newRegistry);

        debugResolver = new DebugResolver(newRegistry);

        bytes32 _resolverUID = registerResolver(address(debugResolver));
        setResolverUID(_resolverUID);
    }

    function testDeployModule() public {
        bytes memory data = bytes(abi.encode(keccak256("data")));
        address module = deployModule({
            code: type(MockValidator).creationCode,
            deployParams: "",
            salt: bytes32(0),
            data: data
        });

        ModuleRecord memory record = getModule(module);
        assertEq(module.code, address(mockValidator).code);
        assertEq(record.resolverUID, resolverUID);
        assertEq(record.implementation, module);
        assertEq(record.sender, address(this));
        assertEq(record.data, data);
    }

    function testDeployModuleCreate3() public {
        bytes memory data = bytes(abi.encode(keccak256("data")));
        address module = deployModuleCreate3({
            code: type(MockValidator).creationCode,
            deployParams: "",
            salt: bytes32(0),
            data: data
        });

        ModuleRecord memory record = getModule(module);
        assertEq(module.code, address(mockValidator).code);
        assertEq(record.resolverUID, resolverUID);
        assertEq(record.implementation, module);
        assertEq(record.sender, address(this));
        assertEq(record.data, data);
    }

    function testDeployModuleViaFactory() public {
        MockValidatorFactory factory = new MockValidatorFactory();
        uint256 salt = 0;
        bytes memory callOnFactory =
            abi.encodeWithSelector(MockValidatorFactory.deployModule.selector, salt);
        bytes memory data = bytes(abi.encode(keccak256("data")));
        address module = deployModuleViaFactory({
            factory: address(factory),
            callOnFactory: callOnFactory,
            data: data
        });
        ModuleRecord memory record = getModule(module);
        assertEq(module.code, address(mockValidator).code);
        assertEq(record.resolverUID, resolverUID);
        assertEq(record.implementation, module);
        assertEq(record.implementation, factory.getModuleAddress(salt));
        assertEq(record.sender, address(this));
        assertEq(record.data, data);
    }

    function testGetResolver() public {
        bytes32 _resolverUID = getResolver();
        assertEq(_resolverUID, resolverUID);
    }

    function testRegisterResolver() public {
        DebugResolver _newDebugResolver =
            new DebugResolver{salt:bytes32(keccak256("test"))}(address(registry));
        bytes32 _resolverUID = registerResolver(address(_newDebugResolver));

        ResolverRecord memory resolver = registry.getResolver(_resolverUID);

        assertEq(address(_newDebugResolver), address(resolver.resolver));
        assertEq(address(this), resolver.schemaOwner);
    }

    function testSetRegistry() public {
        address _registry = makeAddr("registry");
        setRegistry(_registry);
        assertEq(_registry, address(registry));
    }

    function testSetResolverUID() public {
        bytes32 _resolverUID = bytes32(keccak256("test"));
        setResolverUID(_resolverUID);
        assertEq(_resolverUID, resolverUID);
    }
}
