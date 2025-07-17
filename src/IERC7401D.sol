// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.26;

import {IERC7401} from "./IERC7401.sol";

/// @notice ERC7401D interface
/// @author Javzzi with Doodles
/// @author Modified from RMRKNestable by RMRK team (https://github.com/rmrk-team/evm/blob/master/contracts/RMRK/nestable/RMRKNestable.sol)
interface IERC7401D is IERC7401 {
    /**
     * @notice Used to notify listeners that a new child address has been added to the collection.
     * @param childAddress Address of the child contract that was added
     */
    event ChildAddressAdded(address indexed childAddress);

    /**
     * @notice Used to notify listeners that a child address has been removed from the collection.
     * @param childAddress Address of the child contract that was removed
     */
    event ChildAddressRemoved(address indexed childAddress);

    /**
     * @notice Used to notify listeners that a new parent address has been added to the collection.
     * @param parentAddress Address of the parent contract that was added
     */
    event ParentAddressAdded(address indexed parentAddress);

    /**
     * @notice Used to notify listeners that a parent address has been removed from the collection.
     * @param parentAddress Address of the parent contract that was removed
     */
    event ParentAddressRemoved(address indexed parentAddress);

    /**
     * @notice Used to check if a given address is a valid child address.
     * @param childAddress Address to check
     * @return bool indicating whether the address is a valid child address
     */
    function isChildAddress(address childAddress) external view returns (bool);

    /**
     * @notice Used to check if a given address is a valid parent address.
     * @param parentAddress Address to check
     * @return bool indicating whether the address is a valid parent address
     */
    function isParentAddress(
        address parentAddress
    ) external view returns (bool);

    /**
     * @notice Used to retrieve all child addresses.
     * @return An array of addresses representing all child contract addresses
     */
    function childAddresses() external view returns (address[] memory);

    /**
     * @notice Used to retrieve all parent addresses.
     * @return An array of addresses representing all parent contract addresses
     */
    function parentAddresses() external view returns (address[] memory);

    /**
     * @notice Used to retrieve the child tokens of a given parent token for a specific child address.
     * @param parentId ID of the parent token for which to retrieve the child tokens
     * @param childAddress Address of the child token's collection smart contract
     * @return tokenIds An array of token IDs representing the child tokens for the given parent and child address
     */
    function childrenOf(
        uint256 parentId,
        address childAddress
    ) external view returns (uint256[] memory tokenIds);

    /**
     * @notice Used to retrieve a specific child token from a given parent token for a specific child address.
     * @param parentId ID of the parent token for which the child is being retrieved
     * @param childAddress Address of the child token's collection smart contract
     * @param index Index of the child token in the parent token's active child tokens array for the given child address
     * @return tokenId The ID of the child token
     */
    function childOf(
        uint256 parentId,
        address childAddress,
        uint256 index
    ) external view returns (uint256 tokenId);
}
