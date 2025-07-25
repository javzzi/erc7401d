// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721ReceiverRevertMock is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        revert("RevertMock");
    }
}
