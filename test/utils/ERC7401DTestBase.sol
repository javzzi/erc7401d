// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC7401DMock} from "../../src/mocks/ERC7401DMock.sol";
import {ERC165Mock} from "../../src/mocks/ERC165Mock.sol";
import {IERC7401DErrors} from "../../src/IERC7401DErrors.sol";

contract ERC7401DTestBase is Test, IERC7401DErrors {
    string internal constant PARENT_NAME = "Parent Token";
    string internal constant PARENT_SYMBOL = "PT";
    string internal constant CHILD_1_NAME = "Child 1 Token";
    string internal constant CHILD_1_SYMBOL = "C1T";
    string internal constant CHILD_2_NAME = "Child 2 Token";
    string internal constant CHILD_2_SYMBOL = "C2T";

    ERC7401DMock internal erc7401dParent;
    ERC7401DMock internal erc7401dChild1;
    ERC7401DMock internal erc7401dChild2;
    address internal nonERC7401Contract;
    address internal owner;
    address internal other;
    address internal approved;
    address internal operator;
    uint256 internal tokenId;
    uint256 internal parentTokenId;
    uint256 internal childTokenId;

    function setUp() public virtual {
        erc7401dParent = new ERC7401DMock(PARENT_NAME, PARENT_SYMBOL);
        erc7401dChild1 = new ERC7401DMock(CHILD_1_NAME, CHILD_1_SYMBOL);
        erc7401dChild2 = new ERC7401DMock(CHILD_2_NAME, CHILD_2_SYMBOL);
        nonERC7401Contract = address(new ERC165Mock());
        owner = makeAddr("owner");
        other = makeAddr("other");
        approved = makeAddr("approved");
        operator = makeAddr("operator");
        tokenId = 1;
        parentTokenId = 101;
        childTokenId = 1001;
    }
}
