// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC7401} from "src/IERC7401.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BurnTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.safeMint(owner, tokenId, "");
    }

    function test_ShouldDeleteTheOwnerOfTheToken() public {
        vm.prank(owner);
        erc7401dParent.burn(tokenId);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.ownerOf(tokenId);
    }

    function test_ShouldBurnTokenFromApprovedAddress() public {
        vm.prank(owner);
        erc7401dParent.approve(other, tokenId);
        vm.prank(other);
        erc7401dParent.burn(tokenId);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.ownerOf(tokenId);
    }

    function test_ShouldBurnTokenFromOperatorAddress() public {
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(other, true);
        vm.prank(other);
        erc7401dParent.burn(tokenId);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.ownerOf(tokenId);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnBurn() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(owner, address(0), tokenId);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(owner, address(0), 0, 0, tokenId);
        erc7401dParent.burn(tokenId);
    }

    function test_ShouldUpdateBalanceCorrectlyAfterBurn() public {
        vm.prank(owner);
        erc7401dParent.burn(tokenId);
        assertEq(erc7401dParent.balanceOf(owner), 0);
    }

    function test_ShouldDisableApprovalAfterBurn() public {
        vm.startPrank(owner);
        erc7401dParent.approve(other, tokenId);
        erc7401dParent.burn(tokenId, 0);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.getApproved(tokenId);
    }

    function test_ShouldRemoveChildrenValuesOfTheToken() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        vm.prank(owner);
        erc7401dChild1.nestMint(address(erc7401dParent), 1, 1, "");

        vm.prank(owner);
        erc7401dParent.burn(tokenId, 1);
        assertEq(erc7401dParent.childrenOf(tokenId).length, 0);
    }

    function test_ShouldBurnChildrenOfTheTokenInTheirRespectiveContracts() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        vm.prank(owner);
        erc7401dChild1.nestMint(address(erc7401dParent), 1, 1, "");
        vm.prank(owner);
        erc7401dParent.burn(tokenId, 1);

        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dChild1.ownerOf(1);
    }

    function test_RevertWhen_BurningANonExistentToken() public {
        vm.prank(owner);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.burn(999);
    }

    function test_RevertWhen_BurningFromAnAddressThatIsNotTheOwnerOrApprovedOfTheToken() public {
        vm.prank(other);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dParent.burn(tokenId);
    }

    function test_RevertWhen_BurningATokenWithChildrenAndNoMaxChildrenBurnsWasSpecified() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        vm.prank(owner);
        erc7401dChild1.nestMint(address(erc7401dParent), 1, 1, "");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC7401MaxRecursiveBurnsReached.selector, address(erc7401dChild1), 1));
        erc7401dParent.burn(tokenId, 0);
    }

    function test_RevertWhen_MaxRecursiveBurnsIsReached() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dChild1.addChildAddress(address(erc7401dChild2));
        erc7401dChild2.addParentAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(address(erc7401dParent), 1, 1, "");
        vm.prank(owner);
        erc7401dChild2.nestMint(address(erc7401dChild1), 1, 1, "");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC7401MaxRecursiveBurnsReached.selector, address(erc7401dChild2), 1));
        erc7401dParent.burn(tokenId, 1);
    }
}
