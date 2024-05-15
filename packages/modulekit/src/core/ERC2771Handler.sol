// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Handler Context - Allows the fallback handler to extract addition context from the
 * calldata
 * @dev The fallback manager appends the following context to the calldata:
 *      1. Fallback manager caller address (non-padded)
 * based on
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/f8cc8b844a9f92f63dc55aa581f7d643a1bc5ac1
 *    /contracts/metatx/ERC2771Context.sol
 * @author Richard Meissner - @rmeissner
 */
contract ERC2771Handler {
    error ERC2771Unauthorized();

    /**
     * @notice Returns the FallbackManager address
     * @return Fallback manager address
     */
    function _manager() internal view returns (address) {
        return msg.sender;
    }
}
