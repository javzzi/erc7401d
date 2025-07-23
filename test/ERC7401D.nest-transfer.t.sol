// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC7401} from "src/IERC7401.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC7401DMock} from "src/mocks/ERC7401DMock.sol";

contract NestTransferTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.safeMint(owner, childTokenId, "");
    }

    function test_ShouldChangeTheOwnerOfTheTokenToTheDestinationOwner() public {
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(erc7401dChild1.ownerOf(childTokenId), owner);
    }

    function test_ShouldChangeTheDirectOwnerOfTheTokenToTheParentContract()
        public
    {
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        (address directOwner, uint256 tokenId, ) = erc7401dChild1.directOwnerOf(
            childTokenId
        );
        assertEq(directOwner, address(erc7401dParent));
        assertEq(tokenId, parentTokenId);
    }

    function test_ShouldNestTransferATokenFromApprovedAddress() public {
        vm.prank(owner);
        erc7401dChild1.approve(other, childTokenId);
        vm.prank(other);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(erc7401dChild1.ownerOf(childTokenId), owner);
    }

    function test_ShouldNestTransferATokenFromOperatorAddress() public {
        vm.prank(owner);
        erc7401dChild1.setApprovalForAll(other, true);
        vm.prank(other);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(erc7401dChild1.ownerOf(childTokenId), owner);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnNestTransfer()
        public
    {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(owner, address(erc7401dParent), childTokenId);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(
            owner,
            address(erc7401dParent),
            0,
            parentTokenId,
            childTokenId
        );
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function test_ShouldCleanApprovalsForTheTokenAfterNestTransfer() public {
        vm.startPrank(owner);
        erc7401dChild1.approve(other, childTokenId);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(erc7401dChild1.getApproved(childTokenId), address(0));
    }

    function test_ShouldAddChildToTheDestinationToken() public {
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        IERC7401.Child memory child = erc7401dParent.childOf(parentTokenId, 0);
        assertEq(child.contractAddress, address(erc7401dChild1));
        assertEq(child.tokenId, childTokenId);
    }

    function test_ShouldRemoveChildFromTheSourceToken() public {
        vm.startPrank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );

        assertEq(erc7401dParent.childrenOf(parentTokenId).length, 1);

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

    function test_RevertWhen_NestTransferringANonExistentToken() public {
        vm.prank(owner);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            999,
            parentTokenId,
            ""
        );
    }

    function test_RevertWhen_NestTransferringATokenFromAnAddressThatIsNotTheOwnerOrApproved()
        public
    {
        vm.prank(other);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function test_RevertWhen_NestTransferringToANonContractIfTheDestinationIdIsNot0()
        public
    {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ERC7401DInvalidParentAddress.selector, other)
        );
        erc7401dChild1.nestTransferFrom(owner, other, childTokenId, 1, "");
    }

    function test_RevertWhen_NestTransferringToAContractThatIsNotAParent()
        public
    {
        ERC7401DMock newParent = new ERC7401DMock("New", "NEW");
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DInvalidParentAddress.selector,
                address(newParent)
            )
        );
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(newParent),
            childTokenId,
            1,
            ""
        );
    }

    function test_RevertWhen_NestTransferringToANonExistentParentToken()
        public
    {
        vm.prank(owner);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            999,
            ""
        );
    }

    function test_RevertWhen_NestTransferringATokenToItself() public {
        vm.prank(owner);
        vm.expectRevert(ERC7401NestableTransferToSelf.selector);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dChild1),
            childTokenId,
            childTokenId,
            ""
        );
    }

    function test_RevertWhen_NestTransferringToADestinationThatWouldCreateACircularDependency()
        public
    {
        erc7401dParent.addParentAddress(address(erc7401dChild1));
        erc7401dChild1.addChildAddress(address(erc7401dParent));
        vm.prank(owner);
        erc7401dChild1.nestTransferFrom(
            owner,
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        vm.prank(owner);
        vm.expectRevert(ERC7401NestableTransferToDescendant.selector);
        erc7401dParent.nestTransferFrom(
            owner,
            address(erc7401dChild1),
            parentTokenId,
            childTokenId,
            ""
        );
    }
}

contract NestTransferFuzzTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dChild1.addChildAddress(address(erc7401dChild2));
        erc7401dChild2.addParentAddress(address(erc7401dChild1));
    }

    function testFuzz_NestTransfer(
        address from,
        uint256 tokenIdSeed,
        uint256 destinationIdSeed
    ) public {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        uint256 testDestinationId = bound(
            destinationIdSeed,
            2000,
            type(uint128).max
        );
        vm.assume(testTokenId != testDestinationId);

        vm.assume(!erc7401dChild1.exists(testTokenId));
        vm.assume(!erc7401dParent.exists(testDestinationId));

        erc7401dChild1.safeMint(from, testTokenId, "");
        erc7401dParent.safeMint(owner, testDestinationId, "");

        uint256 fromBalance = erc7401dChild1.balanceOf(from);
        uint256 toBalance = erc7401dChild1.balanceOf(address(erc7401dParent));

        vm.prank(from);
        erc7401dChild1.nestTransferFrom(
            from,
            address(erc7401dParent),
            testTokenId,
            testDestinationId,
            ""
        );

        assertEq(erc7401dChild1.balanceOf(from), fromBalance - 1);
        assertEq(
            erc7401dChild1.balanceOf(address(erc7401dParent)),
            toBalance + 1
        );

        (address directOwner, uint256 parentTokenId, ) = erc7401dChild1
            .directOwnerOf(testTokenId);
        assertEq(directOwner, address(erc7401dParent));
        assertEq(parentTokenId, testDestinationId);

        uint256[] memory children = erc7401dParent.childrenOf(
            testDestinationId,
            address(erc7401dChild1)
        );
        bool foundChild = false;
        for (uint256 i = 0; i < children.length; i++) {
            if (children[i] == testTokenId) {
                foundChild = true;
                break;
            }
        }
        assertTrue(foundChild);
    }

    function testFuzz_ChildTransfer(
        uint256 tokenIdSeed,
        uint256 childIndexSeed,
        uint256 destinationIdSeed
    ) public {
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        uint256 testDestinationId = bound(
            destinationIdSeed,
            2000,
            type(uint128).max
        );
        vm.assume(testTokenId != testDestinationId);

        vm.assume(!erc7401dParent.exists(testTokenId));
        vm.assume(!erc7401dParent.exists(testDestinationId));

        erc7401dParent.safeMint(owner, testTokenId, "");
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            testTokenId,
            ""
        );

        uint256[] memory children = erc7401dParent.childrenOf(
            testTokenId,
            address(erc7401dChild1)
        );
        vm.assume(children.length > 0);
        uint256 testChildIndex = bound(childIndexSeed, 0, children.length - 1);

        address to = other;
        uint256 testDestinationIdFinal = 0;

        vm.prank(owner);
        erc7401dParent.transferChild(
            testTokenId,
            to,
            testDestinationIdFinal,
            testChildIndex,
            address(erc7401dChild1),
            children[testChildIndex],
            false,
            ""
        );

        assertEq(erc7401dChild1.ownerOf(children[testChildIndex]), to);
    }

    function testFuzz_NestMint(
        uint256 tokenIdSeed,
        uint256 destinationIdSeed
    ) public {
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        uint256 testDestinationId = bound(
            destinationIdSeed,
            2000,
            type(uint128).max
        );
        vm.assume(testTokenId != testDestinationId);

        vm.assume(!erc7401dChild1.exists(testTokenId));
        vm.assume(!erc7401dParent.exists(testDestinationId));

        erc7401dParent.safeMint(owner, testDestinationId, "");

        uint256 balanceBefore = erc7401dChild1.balanceOf(
            address(erc7401dParent)
        );

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            testTokenId,
            testDestinationId,
            ""
        );

        assertEq(
            erc7401dChild1.balanceOf(address(erc7401dParent)),
            balanceBefore + 1
        );
        assertEq(erc7401dChild1.ownerOf(testTokenId), owner);

        (address directOwner, uint256 parentTokenIdOut, ) = erc7401dChild1
            .directOwnerOf(testTokenId);
        assertEq(directOwner, address(erc7401dParent));
        assertEq(parentTokenIdOut, testDestinationId);
    }

    function testFuzz_RevertWhen_NestTransferToSelf(
        uint256 tokenIdSeed
    ) public {
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner, testTokenId, "");

        vm.prank(owner);
        vm.expectRevert(ERC7401NestableTransferToSelf.selector);
        erc7401dParent.nestTransferFrom(
            owner,
            address(erc7401dParent),
            testTokenId,
            testTokenId,
            ""
        );
    }

    function testFuzz_RevertWhen_NestTransferToDescendant(
        uint256 parentIdSeed,
        uint256 childIdSeed
    ) public {
        uint256 testParentId = bound(parentIdSeed, 1000, type(uint128).max);
        uint256 testChildId = bound(childIdSeed, 2000, type(uint128).max);
        vm.assume(testParentId != testChildId);

        vm.assume(!erc7401dParent.exists(testParentId));
        vm.assume(!erc7401dChild1.exists(testChildId));

        erc7401dParent.safeMint(owner, testParentId, "");
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            testChildId,
            testParentId,
            ""
        );

        erc7401dChild1.addChildAddress(address(erc7401dParent));
        erc7401dParent.addParentAddress(address(erc7401dChild1));

        vm.prank(owner);
        vm.expectRevert(ERC7401NestableTransferToDescendant.selector);
        erc7401dParent.nestTransferFrom(
            owner,
            address(erc7401dChild1),
            testParentId,
            testChildId,
            ""
        );
    }

    function testFuzz_RevertWhen_NestTransferNonexistentToken(
        uint256 tokenIdSeed
    ) public {
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner, parentTokenId, "");

        vm.prank(owner);
        vm.expectRevert(ERC721InvalidTokenId.selector);
        erc7401dParent.nestTransferFrom(
            owner,
            address(erc7401dChild1),
            testTokenId,
            parentTokenId,
            ""
        );
    }

    function testFuzz_RevertWhen_UnauthorizedNestTransfer(
        address unauthorized,
        uint256 tokenIdSeed
    ) public {
        vm.assume(unauthorized != address(0) && unauthorized != owner);
        vm.assume(unauthorized.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1000, type(uint128).max);

        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(owner, testTokenId, "");
        erc7401dParent.safeMint(owner, parentTokenId, "");

        vm.prank(unauthorized);
        vm.expectRevert(ERC7401NotApprovedOrDirectOwner.selector);
        erc7401dParent.nestTransferFrom(
            owner,
            address(erc7401dChild1),
            testTokenId,
            parentTokenId,
            ""
        );
    }

    function invariant_DirectOwnerConsistency() public view {
        // directOwnerOf() should return correct parent token or EOA
        for (uint256 tokenId = 1; tokenId <= 1000; tokenId++) {
            if (erc7401dChild1.exists(tokenId)) {
                (address directOwner, uint256 parentTokenId, ) = erc7401dChild1
                    .directOwnerOf(tokenId);

                if (parentTokenId == 0) {
                    assertEq(directOwner.code.length, 0);
                } else {
                    assertTrue(directOwner.code.length > 0);
                    assertTrue(erc7401dParent.exists(parentTokenId));
                }
            }
        }
    }

    function invariant_CircularDependencyPrevention() public view {
        // No token should be its own ancestor
        for (uint256 tokenId = 1; tokenId <= 1000; tokenId++) {
            if (erc7401dChild1.exists(tokenId)) {
                _checkNoCircularDependency(
                    address(erc7401dChild1),
                    tokenId,
                    tokenId,
                    0
                );
            }
        }
    }

    function _checkNoCircularDependency(
        address contractAddr,
        uint256 originalTokenId,
        uint256 currentTokenId,
        uint256 depth
    ) internal view {
        assertTrue(depth < 100);

        (address directOwner, uint256 parentTokenId, ) = ERC7401DMock(
            contractAddr
        ).directOwnerOf(currentTokenId);

        if (parentTokenId != 0) {
            assertTrue(parentTokenId != originalTokenId);
            _checkNoCircularDependency(
                directOwner,
                originalTokenId,
                parentTokenId,
                depth + 1
            );
        }
    }
}
