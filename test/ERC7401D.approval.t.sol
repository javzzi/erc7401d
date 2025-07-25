// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract ApprovalTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.safeMint(owner, tokenId, "");
    }

    function test_ShouldUpdateTokenApprovalForThatTokenIdAndOwner() public {
        vm.prank(owner);
        erc7401dParent.approve(approved, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), approved);
    }

    function test_ShouldOverrideTokenApprovalForThatTokenIdAndOwnerIfItWasAlreadySet() public {
        vm.prank(owner);
        erc7401dParent.approve(approved, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), approved);

        vm.prank(owner);
        erc7401dParent.approve(other, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), other);
    }

    function test_ShouldApproveFromAnOperatorAddressOfTheOwner() public {
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(operator, true);
        vm.prank(operator);
        erc7401dParent.approve(approved, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), approved);
    }

    function test_ShouldEmitApprovalEventOnApprovingAToken() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Approval(owner, approved, tokenId);
        erc7401dParent.approve(approved, tokenId);
    }

    function test_RevertWhen_ApprovingANonExistentToken() public {
        vm.prank(owner);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.approve(approved, 999);
    }

    function test_RevertWhen_ANonOwnerOrOperatorTriesToApproveAToken() public {
        vm.prank(other);
        vm.expectRevert(ERC721ApproveCallerIsNotOwnerNorApprovedForAll.selector);
        erc7401dParent.approve(approved, tokenId);
    }

    function test_RevertWhen_AnApprovedAddressTriesToChangeTheApprovalOfAToken() public {
        vm.prank(owner);
        erc7401dParent.approve(approved, tokenId);
        vm.prank(approved);
        vm.expectRevert(ERC721ApproveCallerIsNotOwnerNorApprovedForAll.selector);
        erc7401dParent.approve(other, tokenId);
    }

    function test_RevertWhen_ApprovingTheCurrentOwner() public {
        vm.prank(owner);
        vm.expectRevert(ERC721ApprovalToCurrentOwner.selector);
        erc7401dParent.approve(owner, tokenId);
    }

    function test_ShouldSetOperatorApprovalForTheOperatorAddressFromTheMsgSender() public {
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(operator, true);
        assertTrue(erc7401dParent.isApprovedForAll(owner, operator));
    }

    function test_ShouldAllowRevokingOperatorApproval() public {
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(operator, true);
        assertTrue(erc7401dParent.isApprovedForAll(owner, operator));

        vm.prank(owner);
        erc7401dParent.setApprovalForAll(operator, false);
        assertFalse(erc7401dParent.isApprovedForAll(owner, operator));
    }

    function test_ShouldEmitApprovalForAllEventOnSettingOperatorApproval() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.ApprovalForAll(owner, operator, true);
        erc7401dParent.setApprovalForAll(operator, true);
    }

    function test_RevertWhen_TheOperatorIsTheMsgSender() public {
        vm.prank(operator);
        vm.expectRevert(ERC721ApproveToCaller.selector);
        erc7401dParent.setApprovalForAll(operator, true);
    }
}

contract ApprovalFuzzTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_Approve(address operatorAddr, uint256 tokenIdSeed) public {
        vm.assume(operatorAddr != address(0));
        vm.assume(operatorAddr != owner);
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);

        erc7401dParent.safeMint(owner, testTokenId, "");

        vm.prank(owner);
        erc7401dParent.approve(operatorAddr, testTokenId);

        assertEq(erc7401dParent.getApproved(testTokenId), operatorAddr);

        vm.prank(operatorAddr);
        erc7401dParent.transferFrom(owner, other, testTokenId);
        assertEq(erc7401dParent.ownerOf(testTokenId), other);
    }

    function testFuzz_ApprovalClearedOnTransfer(address initialOperator, address newOwner, uint256 tokenIdSeed)
        public
    {
        vm.assume(initialOperator != address(0) && newOwner != address(0));
        vm.assume(initialOperator != owner && newOwner != owner);
        vm.assume(initialOperator != newOwner);
        vm.assume(initialOperator.code.length == 0 && newOwner.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);

        erc7401dParent.safeMint(owner, testTokenId, "");

        vm.prank(owner);
        erc7401dParent.approve(initialOperator, testTokenId);

        assertEq(erc7401dParent.getApproved(testTokenId), initialOperator);

        vm.prank(owner);
        erc7401dParent.transferFrom(owner, newOwner, testTokenId);

        assertEq(erc7401dParent.getApproved(testTokenId), address(0));
    }

    function testFuzz_MultipleApprovals(address operator1, address operator2, uint256 tokenIdSeed) public {
        vm.assume(operator1 != address(0) && operator2 != address(0));
        vm.assume(operator1 != operator2 && operator1 != owner && operator2 != owner);
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);

        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner, testTokenId, "");

        vm.prank(owner);
        erc7401dParent.approve(operator1, testTokenId);
        assertEq(erc7401dParent.getApproved(testTokenId), operator1);

        vm.prank(owner);
        erc7401dParent.approve(operator2, testTokenId);
        assertEq(erc7401dParent.getApproved(testTokenId), operator2);

        vm.prank(operator1);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dParent.transferFrom(owner, other, testTokenId);

        vm.prank(operator2);
        erc7401dParent.transferFrom(owner, other, testTokenId);
        assertEq(erc7401dParent.ownerOf(testTokenId), other);
    }

    function testFuzz_RevertWhen_ApproveNonexistentToken(uint256 tokenIdSeed) public {
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.approve(approved, testTokenId);
    }
}
