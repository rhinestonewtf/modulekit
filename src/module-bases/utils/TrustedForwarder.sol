// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

abstract contract TrustedForwarder {
    // account => trustedForwarder
    mapping(address account => address trustedForwarder) public trustedForwarder;

    /**
     * Set the trusted forwarder for an account
     *
     * @param forwarder The address of the trusted forwarder
     */
    function setTrustedForwarder(address forwarder) external {
        trustedForwarder[msg.sender] = forwarder;
    }

    /**
     * Clear the trusted forwarder for an account
     */
    function clearTrustedForwarder() public {
        trustedForwarder[msg.sender] = address(0);
    }

    /**
     * Check if a forwarder is trusted for an account
     *
     * @param forwarder The address of the forwarder
     * @param account The address of the account
     *
     * @return true if the forwarder is trusted for the account
     */
    function isTrustedForwarder(address forwarder, address account) public view returns (bool) {
        return forwarder == trustedForwarder[account];
    }

    /**
     * Get the sender of the transaction
     *
     * @return account the sender of the transaction
     */
    function _getAccount() internal view returns (address account) {
        account = msg.sender;
        address _account;
        address forwarder;
        if (msg.data.length >= 40) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                _account := shr(96, calldataload(sub(calldatasize(), 20)))
                forwarder := shr(96, calldataload(sub(calldatasize(), 40)))
            }
            if (forwarder == msg.sender && isTrustedForwarder(forwarder, _account)) {
                account = _account;
            }
        }
    }
}
