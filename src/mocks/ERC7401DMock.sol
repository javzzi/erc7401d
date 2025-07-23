// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401D} from "../ERC7401D.sol";

contract ERC7401DMock is ERC7401D {
    constructor(
        string memory name,
        string memory symbol
    ) ERC7401D(name, symbol) {}

    function addChildAddress(address childAddress) public {
        _addChildAddress(childAddress);
    }

    function removeChildAddress(address childAddress) public {
        _removeChildAddress(childAddress);
    }

    function addParentAddress(address parentAddress) public {
        _addParentAddress(parentAddress);
    }

    function removeParentAddress(address parentAddress) public {
        _removeParentAddress(parentAddress);
    }

    function safeMint(address to, uint256 tokenId, bytes memory data) public {
        _safeMint(to, tokenId, data);
    }

    function nestMint(
        address to,
        uint256 tokenId,
        uint256 destinationId,
        bytes memory data
    ) public {
        _nestMint(to, tokenId, destinationId, data);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "mock://";
    }
}
