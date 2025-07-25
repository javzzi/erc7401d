# ERC-7401D: Nestable NFTs for Trusted Ecosystems

[![Foundry][foundry-badge]][foundry]
[![License: Apache-2.0][license-badge]][license]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/Apache-2.0
[license-badge]: https://img.shields.io/badge/License-Apache%202.0-blue.svg

**ERC-7401D** is a simplified implementation of the [ERC-7401](https://eips.ethereum.org/EIPS/eip-7401) standard for nestable Non-Fungible Tokens (NFTs), designed for trusted ecosystems. This implementation focuses on user experience by reducing the number of transactions needed to manage nested NFTs and on security by creating a controlled environment where only trusted collections can interact.

This implementation is used by the Doodles Avatar and Doodles Wearable contracts.

## Core Differences from ERC-7401

ERC-7401D was built to optimize for specific use cases and makes several important deviations from the ERC-7401 implementation by RMRK Team.

### 1. Contract Whitelisting

The standard ERC-7401 is open and permissionless, allowing any contract to nest or be nested. ERC-7401D introduces a whitelisting mechanism for contract interactions. A token can only be nested into a contract that is a registered parent, and a contract can only add a child if it is a registered child contract.

This provides a more controlled and secure environment, preventing unauthorized or spam NFTs from being attached to tokens within the ecosystem.

### 2. Simple Nesting

The standard ERC-7401 uses a two-step process for adding children to a parent token:

1.  **Propose (`addChild`)**: Anyone can "propose" a child to a parent token. This adds the child to a temporary pending list.
2.  **Commit (`acceptChild`)**: The parent token's owner must explicitly accept the child, moving it from the pending list to the active list.

ERC-7401D completely removes this "propose-commit" pattern. The `addChild` function directly adds a child to the list of active children. As a result, the `acceptChild` and `rejectAllChildren` functions are not supported and will revert if called. This simplifies the nesting process and reduces gas costs. Any token from a whitelisted collection can be transferred in without requiring explicit approval for each one.

### 3. No Pending Children

The way child tokens are tracked is fundamentally different.

- **Standard ERC-7401**: Uses two arrays for each parent token: `_activeChildren` and `_pendingChildren`. Both store `Child` structs, which contain the child's `tokenId` and `contractAddress`. This makes it easy to retrieve a list of all children, but requires iterating through the array to find children of a specific contract.
- **ERC-7401D**: Uses a single mapping that groups children by `parentId` and then by their `childAddress`.

```solidity
// Standard ERC-7401: Separate mappings for pending and active children
mapping(uint256 => Child[]) internal _activeChildren;
mapping(uint256 => Child[]) internal _pendingChildren;

// ERC-7401D: Single mapping grouped by contract address
mapping(uint256 => mapping(address => uint256[])) _children;
```

This structure is much more gas-efficient for fetching all children from a specific collection under a parent (`childrenOf(parentId, childAddress)`).

## Example

```solidity
pragma solidity ^0.8.26;

import "./ERC7401D.sol";

contract DoodlesWearable is ERC7401D {
    constructor(address parentAddress) ERC7401D("Doodles Wearables", "WEARABLES") {
        _addParentAddress(parentAddress);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId, "");
    }
}
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This implementation is built upon the work of the [RMRK Team](https://github.com/rmrk-team), who created the original ERC-7401 standard and reference implementation.

---

**Disclaimer**: This software is provided "as is" without warranties. Use at your own risk.
