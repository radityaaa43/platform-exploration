// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @notice ERC-6538 stealth meta-address registry. `registerKeysOnBehalf` (EIP-712) is deliberately
/// not implemented, so this is not fully ERC-6538 compliant. Add it when a compliance claim is needed.
contract ERC6538Registry {
    error InvalidMetaAddressLength();

    event StealthMetaAddressSet(address indexed registrant, uint256 indexed schemeId, bytes stealthMetaAddress);
    event NonceIncremented(address indexed registrant, uint256 newNonce);

    mapping(address => mapping(uint256 => bytes)) public stealthMetaAddressOf;
    mapping(address => uint256) public nonceOf;

    function registerKeys(uint256 schemeId, bytes calldata stealthMetaAddress) external {
        // Scheme 1 meta-address = 33-byte spend pubkey || 33-byte view pubkey.
        if (schemeId == 1 && stealthMetaAddress.length != 66) revert InvalidMetaAddressLength();
        stealthMetaAddressOf[msg.sender][schemeId] = stealthMetaAddress;
        emit StealthMetaAddressSet(msg.sender, schemeId, stealthMetaAddress);
    }

    function incrementNonce() external {
        emit NonceIncremented(msg.sender, ++nonceOf[msg.sender]);
    }
}
