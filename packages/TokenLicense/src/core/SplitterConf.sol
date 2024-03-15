// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "solady/src/auth/Ownable.sol";

contract SplitterConf is Ownable {
    struct Equity {
        uint256[] percentages;
    }

    mapping(address module => Equity equity) internal _moduleEquity;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function getEquity(address module) external view returns (uint256[] memory shares) {
        shares = _moduleEquity[module].percentages;
    }

    function setConf(address module, uint256[] calldata newEquity) external onlyOwner {
        _moduleEquity[module].percentages = newEquity;
    }
}
