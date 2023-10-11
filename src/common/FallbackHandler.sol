// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import { Safe } from "safe-contracts/contracts/Safe.sol";
import "./ERC2771Context.sol";

import "forge-std/console2.sol";

interface IFallbackMethod {
    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        returns (bytes memory result);
}

interface IStaticFallbackMethod {
    function handle(
        address account,
        address sender,
        uint256 value,
        bytes calldata data
    )
        external
        view
        returns (bytes memory result);
}

/**
 * @title Base contract for Extensible Fallback Handlers
 * @dev This contract provides the base for storage and modifiers for extensible fallback handlers
 * @author modified by zeroknots.
 * @author orig contract from: mfw78 <mfw78@rndlabs.xyz>
 */
abstract contract ExtensibleBase is ERC2771Context {
    // --- events ---
    event AddedSafeMethod(address indexed account, bytes4 selector, bytes32 method);
    event ChangedSafeMethod(
        address indexed account, bytes4 selector, bytes32 oldMethod, bytes32 newMethod
    );
    event RemovedSafeMethod(address indexed account, bytes4 selector);

    // --- storage ---

    // A mapping of account => selector => method
    // The method is a bytes32 that is encoded as follows:
    // - The first byte is 0x00 if the method is static and 0x01 if the method is not static
    // - The last 20 bytes are the address of the handler contract
    // The method is encoded / decoded using the MarshalLib
    mapping(address account => mapping(bytes4 => bytes32)) public safeMethods;

    // --- modifiers ---
    modifier onlySelf() {
        // Use the `HandlerContext._msgSender()` to get the caller of the fallback function
        // Use the `HandlerContext._manager()` to get the manager, which should be the Safe
        // Require that the caller is the Safe itself
        require(_msgSender() == _manager(), "only safe can call this method");
        _;
    }

    // --- internal ---

    function _setSafeMethod(address account, bytes4 selector, bytes32 newMethod) internal {
        (, address newHandler) = MarshalLib.decode(newMethod);
        bytes32 oldMethod = safeMethods[account][selector];
        (, address oldHandler) = MarshalLib.decode(oldMethod);

        if (address(newHandler) == address(0) && address(oldHandler) != address(0)) {
            delete safeMethods[account][selector];
            emit RemovedSafeMethod(account, selector);
        } else {
            safeMethods[account][selector] = newMethod;
            if (address(oldHandler) == address(0)) {
                emit AddedSafeMethod(account, selector, newMethod);
            } else {
                emit ChangedSafeMethod(account, selector, oldMethod, newMethod);
            }
        }
    }

    function _getContext() internal view returns (address account, address sender) {
        account = _manager();
        sender = _msgSender();
    }

    function _getContextAndHandler()
        internal
        view
        returns (address account, address sender, bool isStatic, address handler)
    {
        (account, sender) = _getContext();
        (isStatic, handler) = MarshalLib.decode(safeMethods[account][msg.sig]);
    }
}

interface IFallbackHandler {
    function setSafeMethod(bytes4 selector, bytes32 newMethod) external;
}

abstract contract FallbackHandler is ExtensibleBase, IFallbackHandler {
    // --- setters ---

    /**
     * Setter for custom method handlers
     * @param selector The `bytes4` selector of the method to set the handler for
     * @param newMethod A contract that implements the `IFallbackMethod` or `IStaticFallbackMethod` interface
     */
    function setSafeMethod(bytes4 selector, bytes32 newMethod) public override onlySelf {
        console2.log("msg.sender", msg.sender);
        console2.log("address(this)", address(this));
        console2.log("_msgSender", _msgSender());
        _setSafeMethod(payable(msg.sender), selector, newMethod);
    }

    // --- fallback ---

    fallback(bytes calldata) external returns (bytes memory result) {
        require(msg.data.length >= 24, "invalid method selector");
        (address account, address sender, bool isStatic, address handler) = _getContextAndHandler();
        require(handler != address(0), "method handler not set");

        if (isStatic) {
            result = IStaticFallbackMethod(handler).handle(
                account, sender, 0, msg.data[:msg.data.length - 20]
            );
        } else {
            result =
                IFallbackMethod(handler).handle(account, sender, 0, msg.data[:msg.data.length - 20]);
        }
    }
}

library MarshalLib {
    /**
     * Encode a method handler into a `bytes32` value
     * @dev The first byte of the `bytes32` value is set to 0x01 if the method is not static (`view`)
     * @dev The last 20 bytes of the `bytes32` value are set to the address of the handler contract
     * @param isStatic Whether the method is static (`view`) or not
     * @param handler The address of the handler contract implementing the `IFallbackMethod` or `IStaticFallbackMethod` interface
     */
    function encode(bool isStatic, address handler) internal pure returns (bytes32 data) {
        data = bytes32(uint256(uint160(handler)) | (isStatic ? 0 : (1 << 248)));
    }

    function encodeWithSelector(
        bool isStatic,
        bytes4 selector,
        address handler
    )
        internal
        pure
        returns (bytes32 data)
    {
        data = bytes32(
            uint256(uint160(handler)) | (isStatic ? 0 : (1 << 248))
                | (uint256(uint32(selector)) << 216)
        );
    }

    /**
     * Given a `bytes32` value, decode it into a method handler and return it
     * @param data The packed data to decode
     * @return isStatic Whether the method is static (`view`) or not
     * @return handler The address of the handler contract implementing the `IFallbackMethod` or `IStaticFallbackMethod` interface
     */
    function decode(bytes32 data) internal pure returns (bool isStatic, address handler) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // set isStatic to true if the left-most byte of the data is 0x00
            isStatic := iszero(shr(248, data))
            handler := shr(96, shl(96, data))
        }
    }

    function decodeWithSelector(bytes32 data)
        internal
        pure
        returns (bool isStatic, bytes4 selector, address handler)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // set isStatic to true if the left-most byte of the data is 0x00
            isStatic := iszero(shr(248, data))
            handler := shr(96, shl(96, data))
            selector := shl(168, shr(160, data))
        }
    }
}
