// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC7401} from "src/IERC7401.sol";

contract ChildrenTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.safeMint(owner, childTokenId, "");
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function test_ShouldRemoveChildTokenFromChildrenArrayOfTheParentToken()
        public
    {
        vm.prank(owner);
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
        assertEq(erc7401dParent.childrenOf(parentTokenId).length, 0);
    }

    function test_ShouldTransferChildFromApprovedAddress() public {
        vm.prank(owner);
        erc7401dParent.approve(other, parentTokenId);
        vm.prank(other);
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
        assertEq(erc7401dParent.childrenOf(parentTokenId).length, 0);
    }

    function test_ShouldTransferChildFromOperatorAddress() public {
        vm.prank(owner);
        erc7401dParent.setApprovalForAll(other, true);
        vm.prank(other);
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
        assertEq(erc7401dParent.childrenOf(parentTokenId).length, 0);
    }

    function test_ShouldEmitChildTransferredEventOnChildTransfer() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.ChildTransferred(
            parentTokenId,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            false
        );
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnTheChildContractIfTheDestinationIdIs0()
        public
    {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(
            address(erc7401dParent),
            owner,
            parentTokenId,
            0,
            childTokenId
        );
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnTheChildContractIfTheDestinationIdIsNot0()
        public
    {
        uint256 parentTokenId2 = parentTokenId + 1;
        erc7401dParent.safeMint(owner, parentTokenId2, "");

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(
            address(erc7401dParent),
            address(erc7401dParent),
            parentTokenId,
            parentTokenId2,
            childTokenId
        );
        erc7401dParent.transferChild(
            parentTokenId,
            address(erc7401dParent),
            parentTokenId2,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
    }

    function test_RevertWhen_TheInputChildIndexIsNotTheChildIndexInTheChildrenArrayOfTheParentToken()
        public
    {
        vm.prank(owner);
        vm.expectRevert(ERC7401UnexpectedChildId.selector);
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            999,
            false,
            ""
        );
    }

    function test_RevertWhen_TransferringAChildTokenFromAnAddressThatIsNotTheOwnerOrApprovedOfTheToken()
        public
    {
        vm.prank(other);
        vm.expectRevert(ERC721NotApprovedOrOwner.selector);
        erc7401dParent.transferChild(
            parentTokenId,
            owner,
            0,
            0,
            address(erc7401dChild1),
            childTokenId,
            false,
            ""
        );
    }

    function test_ShouldGetTheChildOfATokenByIndex() public view {
        IERC7401.Child memory child = erc7401dParent.childOf(parentTokenId, 0);
        assertEq(child.contractAddress, address(erc7401dChild1));
        assertEq(child.tokenId, childTokenId);
    }

    function test_ShouldGetTheChildOfASpecificChildAddressOfATokenByIndex()
        public
        view
    {
        uint256 childId = erc7401dParent.childOf(
            parentTokenId,
            address(erc7401dChild1),
            0
        );
        assertEq(childId, childTokenId);
    }

    function test_ShouldListAllChildrenOfAToken() public view {
        IERC7401.Child[] memory children = erc7401dParent.childrenOf(
            parentTokenId
        );
        assertEq(children.length, 1);
        assertEq(children[0].contractAddress, address(erc7401dChild1));
        assertEq(children[0].tokenId, childTokenId);
    }

    function test_ShouldListAllChildrenOfASpecificChildAddressOfAToken()
        public
        view
    {
        uint256[] memory childrenIds = erc7401dParent.childrenOf(
            parentTokenId,
            address(erc7401dChild1)
        );
        assertEq(childrenIds.length, 1);
        assertEq(childrenIds[0], childTokenId);
    }

    function test_RevertWhen_GettingChildOfATokenByIndexOutOfRange() public {
        vm.expectRevert(ERC7401ChildIndexOutOfRange.selector);
        erc7401dParent.childOf(parentTokenId, 1);
    }

    function test_RevertWhen_GettingChildOfASpecificChildAddressOfATokenByIndexOutOfRange()
        public
    {
        vm.expectRevert(ERC7401ChildIndexOutOfRange.selector);
        erc7401dParent.childOf(parentTokenId, address(erc7401dChild1), 1);
    }

    function test_ShouldEmitChildAcceptedEventWhenChildIsAdded() public {
        erc7401dChild1.safeMint(owner, 2, "");

        vm.startPrank(owner);
        vm.expectEmit(true, false, true, true);
        emit IERC7401.ChildAccepted(
            parentTokenId,
            1,
            address(erc7401dChild1),
            2
        );

        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            2,
            parentTokenId,
            ""
        );
        vm.stopPrank();
    }
}
