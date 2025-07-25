// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";

contract OwnershipTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.safeMint(owner, parentTokenId, "");
        vm.prank(owner);
        erc7401dChild1.nestMint(address(erc7401dParent), childTokenId, parentTokenId, "");
    }

    function test_ShouldReturnTheOwnerOfAToken() public view {
        assertEq(erc7401dChild1.ownerOf(childTokenId), owner);
    }

    function test_ShouldReturnTheDirectOwnerOfAToken() public view {
        (address directOwner, uint256 tokenId, bool isNFT) = erc7401dChild1.directOwnerOf(childTokenId);
        assertEq(directOwner, address(erc7401dParent));
        assertEq(tokenId, parentTokenId);
        assertTrue(isNFT);
    }

    function test_RevertWhen_QueryingOwnerOfNonExistentToken() public {
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dChild1.ownerOf(999);
    }

    function test_RevertWhen_QueryingDirectOwnerOfNonExistentToken() public {
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dChild1.directOwnerOf(999);
    }
}
