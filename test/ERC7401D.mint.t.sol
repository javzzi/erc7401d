// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {IERC7401} from "src/IERC7401.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC165Mock} from "src/mocks/ERC165Mock.sol";
import {ERC721ReceiverRevertMock} from "src/mocks/ERC721ReceiverRevertMock.sol";
import {ERC7401DMock} from "src/mocks/ERC7401DMock.sol";

contract MintTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ShouldIncreaseTheReceiverBalance() public {
        erc7401dParent.safeMint(owner, tokenId, "");
        assertEq(erc7401dParent.balanceOf(owner), 1);
    }

    function test_ShouldSetTheOwnerOfTheToken() public {
        erc7401dParent.safeMint(owner, tokenId, "");
        assertEq(erc7401dParent.ownerOf(tokenId), owner);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnMint() public {
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(address(0), owner, tokenId);
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(address(0), owner, 0, 0, tokenId);
        erc7401dParent.safeMint(owner, tokenId, "");
    }

    function test_RevertWhen_MintingToTheZeroAddress() public {
        vm.expectRevert(ERC721MintToTheZeroAddress.selector);
        erc7401dParent.safeMint(address(0), tokenId, "");
    }

    function test_RevertWhen_MintingAnExistingTokenId() public {
        erc7401dParent.safeMint(owner, tokenId, "");
        vm.expectRevert(ERC721TokenAlreadyMinted.selector);
        erc7401dParent.safeMint(owner, tokenId, "");
    }

    function test_RevertWhen_MintingTokenId0() public {
        vm.expectRevert(ERC7401IdZeroForbidden.selector);
        erc7401dParent.safeMint(owner, 0, "");
    }

    function test_RevertIf_ReceiverDoesNotImplementERC721Receiver() public {
        ERC165Mock nonReceiver = new ERC165Mock();
        vm.expectRevert(ERC721TransferToNonReceiverImplementer.selector);
        erc7401dParent.safeMint(address(nonReceiver), tokenId, "");
    }

    function test_RevertIf_ReceiverReverts() public {
        ERC721ReceiverRevertMock revertingReceiver = new ERC721ReceiverRevertMock();
        vm.expectRevert(bytes("RevertMock"));
        erc7401dParent.safeMint(address(revertingReceiver), tokenId, "");
    }

    function test_ShouldIncreaseTheReceiverBalanceOnNestMint() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(erc7401dChild1.balanceOf(address(erc7401dParent)), 1);
    }

    function test_ShouldSetTheOwnerOfTheTokenOnNestMint() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        assertEq(
            erc7401dChild1.ownerOf(childTokenId),
            erc7401dParent.ownerOf(parentTokenId)
        );
    }

    function test_ShouldSetTheDirectOwnerOfTheTokenOnNestMint() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        (address directOwner, uint256 directOwnerTokenId, ) = erc7401dChild1
            .directOwnerOf(childTokenId);
        assertEq(directOwner, address(erc7401dParent));
        assertEq(directOwnerTokenId, parentTokenId);
    }

    function test_ShouldEmitTransferAndNestTransferEventsOnNestMint() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(
            address(0),
            address(erc7401dParent),
            childTokenId
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7401.NestTransfer(
            address(0),
            address(erc7401dParent),
            0,
            parentTokenId,
            childTokenId
        );
        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function test_ShouldAddTheChildToTheParentOnNestMint() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        uint256[] memory children = erc7401dParent.childrenOf(
            parentTokenId,
            address(erc7401dChild1)
        );
        assertEq(children.length, 1);
        assertEq(children[0], childTokenId);
    }

    function test_RevertWhen_NestMintingToTheZeroAddress() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DInvalidParentAddress.selector,
                address(0)
            )
        );
        erc7401dChild1.nestMint(address(0), childTokenId, parentTokenId, "");
    }

    function test_RevertWhen_NestMintingAnExistingTokenId() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
        vm.expectRevert(ERC721TokenAlreadyMinted.selector);
        vm.prank(owner);
        erc7401dChild1.nestMint(
            address(erc7401dParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function test_RevertWhen_NestMintingTokenId0() public {
        erc7401dParent.safeMint(owner, parentTokenId, "");
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.prank(owner);
        vm.expectRevert(ERC7401IdZeroForbidden.selector);
        erc7401dChild1.nestMint(address(erc7401dParent), 0, parentTokenId, "");
    }

    function test_RevertWhen_NestMintingToAnAddressThatIsNotAParent() public {
        vm.prank(owner);
        ERC7401DMock newParent = new ERC7401DMock("New", "NEW");
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DInvalidParentAddress.selector,
                address(newParent)
            )
        );
        erc7401dChild1.nestMint(
            address(newParent),
            childTokenId,
            parentTokenId,
            ""
        );
    }

    function testFuzz_Mint(address to, uint256 tokenIdSeed) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);

        uint256 balanceBefore = erc7401dParent.balanceOf(to);
        bool tokenExistsBefore = erc7401dParent.exists(testTokenId);
        vm.assume(!tokenExistsBefore);

        erc7401dParent.safeMint(to, testTokenId, "");

        assertEq(erc7401dParent.balanceOf(to), balanceBefore + 1);
        assertEq(erc7401dParent.ownerOf(testTokenId), to);
        assertTrue(erc7401dParent.exists(testTokenId));

        (address directOwner, uint256 parentTokenIdOut, ) = erc7401dParent
            .directOwnerOf(testTokenId);
        assertEq(directOwner, to);
        assertEq(parentTokenIdOut, 0);
    }

    function testFuzz_SafeMint(
        address to,
        uint256 tokenIdSeed,
        bytes memory data
    ) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);
        vm.assume(!erc7401dParent.exists(testTokenId));

        erc7401dParent.safeMint(to, testTokenId, data);

        assertEq(erc7401dParent.ownerOf(testTokenId), to);
        assertTrue(erc7401dParent.exists(testTokenId));
    }

    function testFuzz_NestMint(
        uint256 tokenIdSeed,
        uint256 destinationIdSeed
    ) public {
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);
        uint256 testDestinationId = bound(
            destinationIdSeed,
            1,
            type(uint128).max
        );
        vm.assume(!erc7401dChild1.exists(testTokenId));

        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dParent.addChildAddress(address(erc7401dChild1));

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

        uint256[] memory children = erc7401dParent.childrenOf(
            testDestinationId,
            address(erc7401dChild1)
        );
        assertEq(children.length, 1);
        assertEq(children[0], testTokenId);
    }

    function testFuzz_RevertWhen_NestMintingToInvalidParent(
        address invalidParent,
        uint256 tokenIdSeed,
        uint256 parentIdSeed
    ) public {
        vm.assume(invalidParent != address(0));
        vm.assume(invalidParent != address(erc7401dParent));
        vm.assume(
            invalidParent.code.length == 0 || invalidParent.code.length > 0
        );
        uint256 testTokenId = bound(tokenIdSeed, 1, type(uint128).max);
        uint256 testParentId = bound(parentIdSeed, 1, type(uint128).max);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DInvalidParentAddress.selector,
                invalidParent
            )
        );
        erc7401dChild1.nestMint(invalidParent, testTokenId, testParentId, "");
    }
}
