// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC7401} from "src/IERC7401.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC165Mock} from "src/mocks/ERC165Mock.sol";
import {ERC721ReceiverRevertMock} from "src/mocks/ERC721ReceiverRevertMock.sol";
import {ERC721ReceiverMock} from "src/mocks/ERC721ReceiverMock.sol";

contract TransferTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.safeMint(owner, tokenId, "");
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(operator, true);
        vm.prank(owner);
        erc7401dParent.approve(approved, tokenId);
    }

    function test_ShouldChangeTheOwnerOfTheTokenToTheReceiver() public {
        vm.prank(owner);
        erc7401dParent.transferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), other);
    }

    function test_ShouldTransferATokenFromApprovedAddress() public {
        vm.prank(approved);
        erc7401dParent.transferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), other);
    }

    function test_ShouldTransferATokenFromOperatorAddress() public {
        vm.prank(operator);
        erc7401dParent.transferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), other);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnTransfer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(owner, other, tokenId);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(owner, other, 0, 0, tokenId);
        erc7401dParent.transferFrom(owner, other, tokenId);
    }

    function test_ShouldUpdateBalancesCorrectlyAfterTransfer() public {
        vm.prank(owner);
        erc7401dParent.transferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.balanceOf(owner), 0);
        assertEq(erc7401dParent.balanceOf(other), 1);
    }

    function test_ShouldCleanApprovalsForThatTokenAfterTransfer() public {
        vm.prank(owner);
        erc7401dParent.transferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), address(0));
    }

    function test_RevertWhen_TransferringANonExistentToken() public {
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.transferFrom(owner, other, 999);
    }

    function test_RevertWhen_TransferringATokenFromAnAddressThatIsNotTheOwnerOrApproved() public {
        vm.prank(other);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dParent.transferFrom(owner, other, tokenId);
    }

    function test_RevertWhen_TransferringToTheZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ERC721TransferToTheZeroAddress.selector);
        erc7401dParent.transferFrom(owner, address(0), tokenId);
    }

    function test_RevertIf_ReceiverReverts() public {
        ERC721ReceiverRevertMock revertingReceiver = new ERC721ReceiverRevertMock();
        vm.prank(owner);
        vm.expectRevert(bytes("RevertMock"));
        erc7401dParent.safeTransferFrom(owner, address(revertingReceiver), tokenId);
    }

    function test_ShouldSafeTransferATokenFromApprovedAddress() public {
        vm.prank(approved);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), other);
    }

    function test_ShouldSafeTransferATokenFromOperatorAddress() public {
        vm.prank(operator);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), other);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnSafeTransfer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(owner, other, tokenId);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(owner, other, 0, 0, tokenId);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
    }

    function test_ShouldUpdateBalancesCorrectlyAfterSafeTransfer() public {
        vm.prank(owner);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.balanceOf(owner), 0);
        assertEq(erc7401dParent.balanceOf(other), 1);
    }

    function test_ShouldCleanApprovalsForThatTokenAfterSafeTransfer() public {
        vm.prank(owner);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
        assertEq(erc7401dParent.getApproved(tokenId), address(0));
    }

    function test_ShouldSafeTransferToAnERC721ReceiverContract() public {
        ERC721ReceiverMock receiver = new ERC721ReceiverMock();
        vm.prank(owner);
        erc7401dParent.safeTransferFrom(owner, address(receiver), tokenId);
        assertEq(erc7401dParent.ownerOf(tokenId), address(receiver));
    }

    function test_RevertWhen_SafeTransferringANonExistentToken() public {
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.safeTransferFrom(owner, other, 999);
    }

    function test_RevertWhen_SafeTransferringATokenFromAnAddressThatIsNotTheOwnerOrApproved() public {
        vm.prank(other);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dParent.safeTransferFrom(owner, other, tokenId);
    }

    function test_RevertWhen_SafeTransferringToTheZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ERC721TransferToTheZeroAddress.selector);
        erc7401dParent.safeTransferFrom(owner, address(0), tokenId);
    }

    function test_RevertIf_ReceiverDoesNotImplementERC721Receiver() public {
        ERC165Mock nonReceiver = new ERC165Mock();
        vm.prank(owner);
        vm.expectRevert(ERC721TransferToNonReceiverImplementer.selector);
        erc7401dParent.safeTransferFrom(owner, address(nonReceiver), tokenId);
    }
}

contract TransferFuzzTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_Transfer(address from, address to, uint256 tokenIdSeed) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(from, testTokenId, "");

        uint256 fromBalanceBefore = erc7401dParent.balanceOf(from);
        uint256 toBalanceBefore = erc7401dParent.balanceOf(to);

        vm.prank(from);
        erc7401dParent.transferFrom(from, to, testTokenId);

        assertEq(erc7401dParent.ownerOf(testTokenId), to);
        assertEq(erc7401dParent.balanceOf(from), fromBalanceBefore - 1);
        assertEq(erc7401dParent.balanceOf(to), toBalanceBefore + 1);

        (address directOwner, uint256 parentTokenIdOut,) = erc7401dParent.directOwnerOf(testTokenId);
        assertEq(directOwner, to);
        assertEq(parentTokenIdOut, 0);
    }

    function testFuzz_SafeTransfer(address from, address to, uint256 tokenIdSeed, bytes memory data) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(from, testTokenId, "");

        vm.prank(from);
        erc7401dParent.safeTransferFrom(from, to, testTokenId, data);

        assertEq(erc7401dParent.ownerOf(testTokenId), to);
    }

    function testFuzz_TransferWithApproval(address owner_, address operator_, address to, uint256 tokenIdSeed) public {
        vm.assume(owner_ != address(0) && operator_ != address(0) && to != address(0));
        vm.assume(owner_ != operator_ && operator_ != to && owner_ != to);
        vm.assume(owner_.code.length == 0 && operator_.code.length == 0 && to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner_, testTokenId, "");

        vm.prank(owner_);
        erc7401dParent.approve(operator_, testTokenId);

        uint256 fromBalanceBefore = erc7401dParent.balanceOf(owner_);
        uint256 toBalanceBefore = erc7401dParent.balanceOf(to);

        vm.prank(operator_);
        erc7401dParent.transferFrom(owner_, to, testTokenId);

        assertEq(erc7401dParent.ownerOf(testTokenId), to);
        assertEq(erc7401dParent.balanceOf(owner_), fromBalanceBefore - 1);
        assertEq(erc7401dParent.balanceOf(to), toBalanceBefore + 1);
        assertEq(erc7401dParent.getApproved(testTokenId), address(0));
    }

    function testFuzz_TransferWithApprovalForAll(address owner_, address operator_, address to, uint256 tokenIdSeed)
        public
    {
        vm.assume(owner_ != address(0) && operator_ != address(0) && to != address(0));
        vm.assume(owner_ != operator_ && operator_ != to && owner_ != to);
        vm.assume(owner_.code.length == 0 && operator_.code.length == 0 && to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner_, testTokenId, "");

        vm.prank(owner_);
        erc7401dParent.setApprovalForAll(operator_, true);

        vm.prank(operator_);
        erc7401dParent.transferFrom(owner_, to, testTokenId);

        assertEq(erc7401dParent.ownerOf(testTokenId), to);
        assertTrue(erc7401dParent.isApprovedForAll(owner_, operator_));
    }
}
