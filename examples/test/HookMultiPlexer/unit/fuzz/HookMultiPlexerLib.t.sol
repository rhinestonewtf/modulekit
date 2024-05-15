// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import {
    HookMultiPlexer,
    SigHookInit,
    HookMultiPlexerLib,
    HookType,
    HookAndContext
} from "src/HookMultiPlexer/HookMultiPlexer.sol";
import { IERC7579Account, IERC7579Module, IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import {
    ModeLib,
    CALLTYPE_DELEGATECALL,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT,
    ModePayload
} from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { MockRegistry } from "test/mocks/MockRegistry.sol";
import { MockHook } from "test/mocks/MockHook.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Solarray } from "solarray/Solarray.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { HookMultiPlexerLib } from "src/HookMultiPlexer/HookMultiPlexerLib.sol";

contract HookMultiPlexerLibExternal {
    using HookMultiPlexerLib for *;

    address[] public array;
    bytes4[] public bytes4Array;

    function requireSortedAndUnique(address[] calldata _array) external pure {
        _array.requireSortedAndUnique();
    }

    function indexOf(address[] calldata _array, address _element) external returns (uint256) {
        array = _array;
        return array.indexOf(_element);
    }

    function indexOf(bytes4[] calldata _array, bytes4 _element) external returns (uint256) {
        bytes4Array = _array;
        return bytes4Array.indexOf(_element);
    }

    function pushUnique(
        bytes4[] calldata _array,
        bytes4 _element
    )
        external
        returns (bytes4[] memory)
    {
        bytes4Array = _array;
        bytes4Array.pushUnique(_element);
        return bytes4Array;
    }

    function popBytes4(
        bytes4[] calldata _array,
        bytes4 _element
    )
        external
        returns (bytes4[] memory)
    {
        bytes4Array = _array;
        bytes4Array.popBytes4(_element);
        return bytes4Array;
    }

    function popAddress(
        address[] calldata _array,
        address _element
    )
        external
        returns (address[] memory)
    {
        array = _array;
        array.popAddress(_element);
        return array;
    }
}

contract HookMultiPlexerLibFuzzTest is BaseTest {
    using LibSort for address[];
    using LibSort for uint256[];
    using HookMultiPlexerLib for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    HookMultiPlexerLibExternal libExternal;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();

        libExternal = new HookMultiPlexerLibExternal();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testFuzz_Join(address[] memory a, address[] memory b) public {
        uint256 aLength = a.length;
        uint256 bLength = b.length;
        vm.assume(aLength < 50);
        vm.assume(bLength < 50);
        for (uint256 i = 0; i < aLength; i++) {
            vm.assume(a[i] != address(0));
        }
        for (uint256 j = 0; j < bLength; j++) {
            vm.assume(b[j] != address(0));
        }

        address[] memory joinedArray = new address[](aLength + bLength);

        for (uint256 i = 0; i < aLength; i++) {
            joinedArray[i] = a[i];
        }

        for (uint256 j = 0; j < bLength; j++) {
            joinedArray[aLength + j] = b[j];
        }

        a.join(b);

        assertEq(a.length, joinedArray.length);

        uint256 found;
        for (uint256 i = 0; i < a.length; i++) {
            address element = a[i];
            for (uint256 j = 0; j < joinedArray.length; j++) {
                if (element == joinedArray[j]) {
                    found++;
                    break;
                }
            }
        }
        assertEq(found, a.length);
    }

    function testFuzz_Join_WithUints(uint8 a, uint8 b) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(a < 20);
        vm.assume(b < 20);
        address[] memory aArray = new address[](a);
        address[] memory bArray = new address[](b);

        for (uint256 i = 0; i < a; i++) {
            aArray[i] = address(uint160(i + 1));
        }

        for (uint256 i = 0; i < b; i++) {
            bArray[i] = address(uint160(40 + i + 1));
        }

        aArray.join(bArray);

        assertEq(aArray.length, a + b);
    }

    function testFuzz_RequireSortedAndUnique(address[] memory array) public {
        array.sort();
        array.uniquifySorted();

        libExternal.requireSortedAndUnique(array);
    }

    function testFuzz_IndexOf(address[] memory array, address element) public {
        vm.assume(array.length > 0);

        uint256 index = libExternal.indexOf(array, element);

        if (index == type(uint256).max) {
            for (uint256 i = 0; i < array.length; i++) {
                assertNotEq(array[i], element);
            }
        } else {
            assertEq(array[index], element);
        }
    }

    function testFuzz_IndexOf_Bytes4(bytes4[] memory array, bytes4 element) public {
        vm.assume(array.length > 0);

        uint256 index = libExternal.indexOf(array, element);

        if (index == type(uint256).max) {
            for (uint256 i = 0; i < array.length; i++) {
                assertNotEq(array[i], element);
            }
        } else {
            assertEq(array[index], element);
        }
    }

    function testFuzz_PushUnique(bytes4[] memory array, bytes4 element) public {
        vm.assume(array.length > 0);
        vm.assume(element != bytes4(0));

        for (uint256 i = 0; i < array.length; i++) {
            vm.assume(array[i] != bytes4(0));
        }

        bytes4[] memory newArray = libExternal.pushUnique(array, element);

        bool found;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                found = true;
                break;
            }
        }
        if (found) {
            assertEq(newArray.length, array.length);
        } else {
            assertEq(newArray.length, array.length + 1);
        }
    }

    function testFuzz_PopBytes4(bytes4[] memory array, bytes4 element) public {
        vm.assume(array.length > 0);
        vm.assume(element != bytes4(0));

        for (uint256 i = 0; i < array.length; i++) {
            vm.assume(array[i] != bytes4(0));
        }

        bytes4[] memory newArray = libExternal.popBytes4(array, element);

        bool found;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                found = true;
                break;
            }
        }
        if (found) {
            assertEq(newArray.length, array.length - 1);
        } else {
            assertEq(newArray.length, array.length);
        }
    }

    function testFuzz_PopAddress(address[] memory array, address element) public {
        vm.assume(array.length > 0);
        vm.assume(element != address(0));

        for (uint256 i = 0; i < array.length; i++) {
            vm.assume(array[i] != address(0));
        }

        address[] memory newArray = libExternal.popAddress(array, element);

        bool found;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                found = true;
                break;
            }
        }
        if (found) {
            assertEq(newArray.length, array.length - 1);
        } else {
            assertEq(newArray.length, array.length);
        }
    }
}
