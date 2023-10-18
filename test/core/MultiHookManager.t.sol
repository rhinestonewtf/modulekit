// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../../src/test/utils/safe-base/RhinestoneModuleKit.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { MockExecutor } from "../../src/test/mocks/MockExecutor.sol";

import {
    IExecutorBase, ModuleExecLib, IExecutorManager
} from "../../src/modulekit/ExecutorBase.sol";

import "forge-std/interfaces/IERC721.sol";

import "../../src/modulekit/MultiHookManager.sol";

/// @title HookManagerTest
/// @author zeroknots

contract VirtualColdStorage721 is IHook {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct ConfToken {
        EnumerableSet.AddressSet tokenAddresses;
        mapping(address tokenAddress => EnumerableSet.UintSet) tokenIds;
    }

    error UnauthorizedTokenTransfer();
    error InvalidTokenContract(address tokenContract);
    error TokenAlreadyBlacklisted(address tokenContract);

    mapping(address account => ConfToken) _coldStorage;

    function _addToColdStorage(address account, address tokenContract, uint256 tokenId) internal {
        if (tokenContract == address(0)) revert InvalidTokenContract(tokenContract);

        ConfToken storage conf = _coldStorage[account];
        if (_isTokenInStorage(conf, tokenContract, tokenId)) {
            revert InvalidTokenContract(tokenContract);
        }

        conf.tokenAddresses.add(tokenContract);
        conf.tokenIds[tokenContract].add(tokenId);
    }

    function addToColdStorage(address tokenContract, uint256 tokenId) external {
        _addToColdStorage(msg.sender, tokenContract, tokenId);
    }

    function _isTokenInStorage(
        ConfToken storage conf,
        address tokenContract,
        uint256 tokenId
    )
        internal
        view
        returns (bool)
    {
        if (conf.tokenAddresses.contains(tokenContract)) {
            if (conf.tokenIds[tokenContract].contains(tokenId)) {
                return true;
            }
        }
    }

    function _getApprovers(
        address tokenAddress,
        uint256[] memory tokenIds
    )
        internal
        returns (address[] memory approvers)
    {
        uint256 tokenIdsLength = tokenIds.length;
        approvers = new address[](tokenIdsLength);
        for (uint256 i; i < tokenIdsLength; i++) {
            approvers[i] = IERC721(tokenAddress).getApproved(tokenIds[i]);
        }
        return approvers;
    }

    function _enforceStillOwner(
        address owner,
        address tokenAddress,
        uint256[] memory tokenIds
    )
        internal
    {
        uint256 tokenIdsLength = tokenIds.length;
        for (uint256 i; i < tokenIdsLength; i++) {
            if (IERC721(tokenAddress).ownerOf(tokenIds[i]) != owner) {
                revert UnauthorizedTokenTransfer();
            }
        }
    }

    function _enforceStillOwner(address owner, address[] memory allTokens) internal {
        uint256 allTokenLength = allTokens.length;
        address[][] memory approversPerToken = new address[][](allTokenLength);
        for (uint256 i; i < allTokenLength; i++) {
            address tokenAddress = allTokens[i];
            uint256[] memory allTokenIds = _coldStorage[owner].tokenIds[tokenAddress].values();
            _enforceStillOwner(owner, tokenAddress, allTokenIds);
        }
    }

    function _getAllApprovers(
        address account,
        address[] memory allTokens
    )
        public
        returns (address[][] memory)
    {
        uint256 allTokenLength = allTokens.length;
        address[][] memory approversPerToken = new address[][](allTokenLength);
        for (uint256 i; i < allTokenLength; i++) {
            address tokenAddress = allTokens[i];
            uint256[] memory allTokenIds = _coldStorage[account].tokenIds[tokenAddress].values();
            approversPerToken[i] = _getApprovers(tokenAddress, allTokenIds);
        }
        return approversPerToken;
    }

    function preCheck(
        address account,
        ExecutorTransaction calldata transaction,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    {
        address[] memory allTokens = _coldStorage[account].tokenAddresses.values();
        address[][] memory approversPerToken = _getAllApprovers(account, allTokens);
        // get checksum of approversPerToken
        bytes32 checksum = keccak256(abi.encode(approversPerToken));
        preCheckData = abi.encode(checksum);
    }

    function preCheckRootAccess(
        address account,
        ExecutorTransaction calldata rootAccess,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        override
        returns (bytes memory preCheckData)
    { }

    function postCheck(
        address account,
        bool success,
        bytes calldata preCheckData
    )
        external
        override
    {
        address[] memory allTokens = _coldStorage[account].tokenAddresses.values();
        address[][] memory approversPerToken = _getAllApprovers(account, allTokens);
        bytes32 checksum = keccak256(abi.encode(approversPerToken));

        bytes32 preChecksum = abi.decode(preCheckData, (bytes32));

        if (checksum != preChecksum) revert UnauthorizedTokenTransfer();

        _enforceStillOwner(account, allTokens);
    }
}

contract HookManagerTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;
    MockExecutor executor;
    MultiHookManager multiHookManager;

    address receiver;

    MockERC721 token;

    function setUp() public {
        receiver = makeAddr("receiver");

        // setting up mock executor and token
        executor = new MockExecutor();
        token = new MockERC721("", "");
        multiHookManager = new MultiHookManager();

        // create a new rhinestone account instance
        instance = makeRhinestoneAccount("1");

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 1);
        token.mint(instance.account, 2);
    }

    function testHookExecution() public {
        instance.addExecutor(address(executor));
        instance.addHook(address(multiHookManager));

        executor.execCalldata(
            IExecutorManager(address(instance.aux.executorManager)),
            instance.account,
            address(token),
            abi.encodeWithSelector(IERC721.transferFrom.selector, instance.account, receiver, 1)
        );

        VirtualColdStorage721 nftHook = new VirtualColdStorage721();
        vm.prank(instance.account);
        multiHookManager.addSubHook(address(nftHook));

        vm.prank(instance.account);
        nftHook.addToColdStorage(address(token), 2);

        vm.expectRevert(
            abi.encodeWithSelector(VirtualColdStorage721.UnauthorizedTokenTransfer.selector)
        );
        executor.execCalldata(
            IExecutorManager(address(instance.aux.executorManager)),
            instance.account,
            address(token),
            abi.encodeWithSelector(IERC721.transferFrom.selector, instance.account, receiver, 2)
        );
    }
}
