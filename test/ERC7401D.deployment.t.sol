// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";

contract DeploymentTest is ERC7401DTestBase {
    function test_ShouldInitializeWithCorrectNameAndSymbol() public view {
        assertEq(erc7401dParent.name(), PARENT_NAME);
        assertEq(erc7401dParent.symbol(), PARENT_SYMBOL);
    }
}
