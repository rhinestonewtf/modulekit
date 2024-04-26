// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import { Solarray } from "solarray/Solarray.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract OptimizationTest is Test {
    address[] arr;

    using LibSort for address[];

    function flatten(
        address[] storage globalHooks,
        address[] storage valueHooks,
        address[] storage sigHooks
    )
        internal
        returns (address[] memory flat)
    {
        uint256 gLength = globalHooks.length;
        uint256 vLength = valueHooks.length;
        uint256 sLength = sigHooks.length;
        uint256 totalLength = gLength + vLength + sLength;
        uint256 iter;
        flat = new address[](totalLength);
        for (uint256 i; i < gLength; i++) {
            flat[i] = globalHooks[i];
        }
        iter += gLength;

        for (uint256 i; i < vLength; i++) {
            flat[iter + i] = valueHooks[i];
        }
        iter += vLength;
        for (uint256 i; i < sLength; i++) {
            flat[iter + i] = valueHooks[i];
        }
    }

    function setUp() public { }

    function test_flatten() public {
        arr = Solarray.addresses(
            address(0x4141414141414141), address(0x4242424242424242), address(0x4343434343434343)
        );

        address[] memory _arr = flatten(arr, arr, arr);
        assertEq(_arr.length, 9);
        assertEq(_arr[0], address(0x4141414141414141));
        assertEq(_arr[1], address(0x4242424242424242));
        assertEq(_arr[2], address(0x4343434343434343));
        assertEq(_arr[3], address(0x4141414141414141));
        assertEq(_arr[4], address(0x4242424242424242));
        assertEq(_arr[5], address(0x4343434343434343));
        assertEq(_arr[6], address(0x4141414141414141));
        assertEq(_arr[7], address(0x4242424242424242));
        assertEq(_arr[8], address(0x4343434343434343));
        _arr.sort();
        _arr.uniquifySorted();
        assertEq(_arr.length, 3);
        assertEq(_arr[0], address(0x4141414141414141));
        assertEq(_arr[1], address(0x4242424242424242));
        assertEq(_arr[2], address(0x4343434343434343));
    }
}
