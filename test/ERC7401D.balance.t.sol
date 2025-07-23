// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";

contract BalanceTest is ERC7401DTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ShouldReturnZeroIfOwnerHasNoTokens() public view {
        assertEq(erc7401dParent.balanceOf(owner), 0);
    }

    function test_ShouldReturnCorrectBalanceIfOwnerHasTokens() public {
        erc7401dParent.safeMint(owner, tokenId, "");
        assertEq(erc7401dParent.balanceOf(owner), 1);
    }

    function testFuzz_BalanceAfterMints(
        address to,
        uint256 numMintsSeed
    ) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        uint256 numMints = bound(numMintsSeed, 1, 20);

        for (uint256 i = 0; i < numMints; i++) {
            uint256 testTokenId = 1000 + i;
            vm.assume(!erc7401dParent.exists(testTokenId));
            erc7401dParent.safeMint(to, testTokenId, "");
        }

        assertEq(erc7401dParent.balanceOf(to), numMints);
    }

    function testFuzz_BalanceAfterTransfers(
        address from,
        address to,
        uint256 numTransfersSeed
    ) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);
        uint256 numTransfers = bound(numTransfersSeed, 1, 10);

        uint256[] memory tokenIds = new uint256[](numTransfers);
        for (uint256 i = 0; i < numTransfers; i++) {
            tokenIds[i] = 1000 + i;
            vm.assume(!erc7401dParent.exists(tokenIds[i]));
            erc7401dParent.safeMint(from, tokenIds[i], "");
        }

        uint256 fromBalanceBefore = erc7401dParent.balanceOf(from);
        uint256 toBalanceBefore = erc7401dParent.balanceOf(to);

        for (uint256 i = 0; i < numTransfers; i++) {
            vm.prank(from);
            erc7401dParent.transferFrom(from, to, tokenIds[i]);
        }

        assertEq(
            erc7401dParent.balanceOf(from),
            fromBalanceBefore - numTransfers
        );
        assertEq(erc7401dParent.balanceOf(to), toBalanceBefore + numTransfers);
    }

    function testFuzz_BalanceAfterBurns(uint256 numBurnsSeed) public {
        uint256 numBurns = bound(numBurnsSeed, 1, 10);

        uint256[] memory tokenIds = new uint256[](numBurns);
        for (uint256 i = 0; i < numBurns; i++) {
            tokenIds[i] = 1000 + i;
            vm.assume(!erc7401dParent.exists(tokenIds[i]));
            erc7401dParent.safeMint(owner, tokenIds[i], "");
        }

        uint256 balanceBefore = erc7401dParent.balanceOf(owner);

        for (uint256 i = 0; i < numBurns; i++) {
            vm.prank(owner);
            erc7401dParent.burn(tokenIds[i], 0);
        }

        assertEq(erc7401dParent.balanceOf(owner), balanceBefore - numBurns);
    }

    function testFuzz_BalanceConsistency(
        address addr1,
        address addr2,
        uint256 mintsSeed,
        uint256 transfersSeed,
        uint256 burnsSeed
    ) public {
        vm.assume(addr1 != address(0) && addr2 != address(0));
        vm.assume(addr1 != addr2);
        vm.assume(addr1.code.length == 0 && addr2.code.length == 0);

        uint256 numMints = bound(mintsSeed, 1, 8);
        uint256 numTransfers = bound(transfersSeed, 0, numMints);
        uint256 numBurns = bound(burnsSeed, 0, numMints - numTransfers);

        uint256[] memory tokenIds = new uint256[](numMints);

        for (uint256 i = 0; i < numMints; i++) {
            tokenIds[i] = 1000 + i;
            vm.assume(!erc7401dParent.exists(tokenIds[i]));
            erc7401dParent.safeMint(addr1, tokenIds[i], "");
        }

        uint256 addr1BalanceAfterMints = erc7401dParent.balanceOf(addr1);
        assertEq(addr1BalanceAfterMints, numMints);

        for (uint256 i = 0; i < numTransfers; i++) {
            vm.prank(addr1);
            erc7401dParent.transferFrom(addr1, addr2, tokenIds[i]);
        }

        uint256 addr1BalanceAfterTransfers = erc7401dParent.balanceOf(addr1);
        uint256 addr2BalanceAfterTransfers = erc7401dParent.balanceOf(addr2);
        assertEq(addr1BalanceAfterTransfers, numMints - numTransfers);
        assertEq(addr2BalanceAfterTransfers, numTransfers);

        for (uint256 i = numTransfers; i < numTransfers + numBurns; i++) {
            vm.prank(addr1);
            erc7401dParent.burn(tokenIds[i], 0);
        }

        uint256 addr1BalanceAfterBurns = erc7401dParent.balanceOf(addr1);
        assertEq(addr1BalanceAfterBurns, numMints - numTransfers - numBurns);

        uint256 totalBalanceAfter = addr1BalanceAfterBurns +
            addr2BalanceAfterTransfers;
        uint256 expectedTotalBalance = numMints - numBurns;
        assertEq(totalBalanceAfter, expectedTotalBalance);
    }

    function testFuzz_BalanceOfMultipleAddresses(
        address addr1,
        address addr2,
        address addr3,
        uint256 mint1Seed,
        uint256 mint2Seed,
        uint256 mint3Seed
    ) public {
        vm.assume(
            addr1 != address(0) && addr2 != address(0) && addr3 != address(0)
        );
        vm.assume(
            addr1.code.length == 0 &&
                addr2.code.length == 0 &&
                addr3.code.length == 0
        );
        vm.assume(addr1 != addr2 && addr2 != addr3 && addr1 != addr3);

        uint256 mint1Count = bound(mint1Seed, 0, 5);
        uint256 mint2Count = bound(mint2Seed, 0, 5);
        uint256 mint3Count = bound(mint3Seed, 0, 5);

        uint256 totalMints = 0;
        uint256 currentTokenId = 1000;

        address[3] memory addresses = [addr1, addr2, addr3];
        uint256[3] memory mintCounts = [mint1Count, mint2Count, mint3Count];

        for (uint256 i = 0; i < 3; i++) {
            uint256 balanceBefore = erc7401dParent.balanceOf(addresses[i]);

            for (uint256 j = 0; j < mintCounts[i]; j++) {
                vm.assume(!erc7401dParent.exists(currentTokenId));
                erc7401dParent.safeMint(addresses[i], currentTokenId, "");
                currentTokenId++;
            }

            uint256 balanceAfter = erc7401dParent.balanceOf(addresses[i]);
            assertEq(balanceAfter, balanceBefore + mintCounts[i]);
            totalMints += mintCounts[i];
        }

        uint256 sumOfBalances = 0;
        for (uint256 i = 0; i < 3; i++) {
            sumOfBalances += erc7401dParent.balanceOf(addresses[i]);
        }
        assertGe(sumOfBalances, totalMints);
    }

    function testFuzz_BalanceWithNestedTokens(
        address owner_,
        uint256 nestedMintsSeed
    ) public {
        vm.assume(owner_ != address(0));
        vm.assume(owner_.code.length == 0);
        uint256 numNestedMints = bound(nestedMintsSeed, 1, 5);

        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        uint256 parentTokenId = 1000;
        vm.assume(!erc7401dParent.exists(parentTokenId));
        erc7401dParent.safeMint(owner_, parentTokenId, "");

        uint256 parentContractBalanceBefore = erc7401dChild1.balanceOf(
            address(erc7401dParent)
        );

        for (uint256 i = 0; i < numNestedMints; i++) {
            uint256 childTokenId = 2000 + i;
            vm.assume(!erc7401dChild1.exists(childTokenId));

            vm.prank(owner_);
            erc7401dChild1.nestMint(
                address(erc7401dParent),
                childTokenId,
                parentTokenId,
                ""
            );
        }

        uint256 parentContractBalanceAfter = erc7401dChild1.balanceOf(
            address(erc7401dParent)
        );
        assertEq(
            parentContractBalanceAfter,
            parentContractBalanceBefore + numNestedMints
        );

        for (uint256 i = 0; i < numNestedMints; i++) {
            uint256 childTokenId = 2000 + i;
            assertEq(erc7401dChild1.ownerOf(childTokenId), owner_);
        }
    }

    mapping(address => uint256) public ghost_balances;
    uint256 public ghost_totalSupply;
    address[] public ghost_tokenOwners;
    mapping(uint256 => bool) public ghost_tokenExists;

    function invariant_BalanceConsistency() public view {
        // Sum of all balances should equal total minted minus total burned
        uint256 sumOfBalances = 0;
        for (uint256 i = 0; i < ghost_tokenOwners.length; i++) {
            sumOfBalances += erc7401dParent.balanceOf(ghost_tokenOwners[i]);
        }

        assertEq(sumOfBalances, ghost_totalSupply);
    }

    function invariant_OwnershipConsistency() public view {
        // Every existing token should have exactly one owner
        for (uint256 tokenId = 1; tokenId <= 1000; tokenId++) {
            if (ghost_tokenExists[tokenId]) {
                address tokenOwner = erc7401dParent.ownerOf(tokenId);
                assertTrue(tokenOwner != address(0));

                uint256 ownerBalance = erc7401dParent.balanceOf(tokenOwner);
                assertGt(ownerBalance, 0);
            }
        }
    }

    function invariant_DirectOwnershipConsistency() public view {
        // Direct ownership should be consistent with regular ownership for root tokens
        for (uint256 tokenId = 1; tokenId <= 1000; tokenId++) {
            if (!ghost_tokenExists[tokenId]) {
                continue;
            }

            address regularOwner = erc7401dParent.ownerOf(tokenId);
            (address directOwner, uint256 parentTokenId, ) = erc7401dParent
                .directOwnerOf(tokenId);

            if (parentTokenId == 0) {
                assertEq(directOwner, regularOwner);
            } else {
                assertTrue(directOwner.code.length > 0);
            }
        }
    }

    function _updateGhostState(
        address owner_,
        uint256 tokenId_,
        bool exists
    ) internal {
        ghost_tokenExists[tokenId_] = exists;

        if (exists) {
            ghost_totalSupply++;

            bool ownerExists = false;
            for (uint256 i = 0; i < ghost_tokenOwners.length; i++) {
                if (ghost_tokenOwners[i] == owner_) {
                    ownerExists = true;
                    break;
                }
            }
            if (!ownerExists) {
                ghost_tokenOwners.push(owner_);
            }
        } else if (ghost_totalSupply > 0) {
            ghost_totalSupply--;
        }
    }

    function helper_mint(address to, uint256 tokenId_) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.assume(tokenId_ > 0 && tokenId_ <= 1000);
        vm.assume(!ghost_tokenExists[tokenId_]);

        erc7401dParent.safeMint(to, tokenId_, "");
        _updateGhostState(to, tokenId_, true);
    }

    function helper_burn(uint256 tokenId_) public {
        vm.assume(tokenId_ > 0 && tokenId_ <= 1000);
        vm.assume(ghost_tokenExists[tokenId_]);

        address tokenOwner = erc7401dParent.ownerOf(tokenId_);
        vm.prank(tokenOwner);
        erc7401dParent.burn(tokenId_, 0);
        _updateGhostState(tokenOwner, tokenId_, false);
    }

    function helper_transfer(
        address from,
        address to,
        uint256 tokenId_
    ) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);
        vm.assume(tokenId_ > 0 && tokenId_ <= 1000);
        vm.assume(ghost_tokenExists[tokenId_]);
        vm.assume(erc7401dParent.ownerOf(tokenId_) == from);

        vm.prank(from);
        erc7401dParent.transferFrom(from, to, tokenId_);

        bool ownerExists = false;
        for (uint256 i = 0; i < ghost_tokenOwners.length; i++) {
            if (ghost_tokenOwners[i] == to) {
                ownerExists = true;
                break;
            }
        }
        if (!ownerExists) {
            ghost_tokenOwners.push(to);
        }
    }
}
