// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Safe7579DCUtil } from "../utils/DCUtil.sol";

contract Safe7579DCUtilSetup {
    address internal UTIL;

    constructor() {
        UTIL = address(new Safe7579DCUtil());
    }
}
