// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract ERC165Mock is IERC165 {
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
