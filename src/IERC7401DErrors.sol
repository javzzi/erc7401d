// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.26;

/**
 * @dev Interface for custom errors in ERC-7401D.
 */
interface IERC7401DErrors {
    /**
     * @dev Attempting to grant the token to the zero address.
     */
    error ERC721AddressZeroIsNotaValidOwner();

    /**
     * @dev Attempting to grant approval to the current owner of the token.
     */
    error ERC721ApprovalToCurrentOwner();

    /**
     * @dev Attempting to grant approval when not being owner or approved for all.
     */
    error ERC721ApproveCallerIsNotOwnerNorApprovedForAll();

    /**
     * @dev Attempting to grant approval to self.
     */
    error ERC721ApproveToCaller();

    /**
     * @dev Attempting to use an invalid token ID.
     */
    error ERC721InvalidTokenId();

    /**
     * @dev Attempting to mint to the zero address.
     */
    error ERC721MintToTheZeroAddress();

    /**
     * @dev Attempting to manage a token without being its owner or approved by the owner.
     */
    error ERC721NotApprovedOrOwner();

    /**
     * @dev Attempting to mint an already minted token.
     */
    error ERC721TokenAlreadyMinted();

    /**
     * @dev Attempting to transfer the token from an address that is not the owner.
     */
    error ERC721TransferFromIncorrectOwner();

    /**
     * @dev Attempting to safe transfer to an address that is unable to receive the token.
     */
    error ERC721TransferToNonReceiverImplementer();

    /**
     * @dev Attempting to transfer the token to the zero address.
     */
    error ERC721TransferToTheZeroAddress();

    /**
     * @dev Attempting to interact with a child using an index that is higher than the number of children.
     */
    error ERC7401ChildIndexOutOfRange();

    /**
     * @dev Attempting to use ID 0, which is not supported.
     * The ID 0 in ERC7401 is reserved for empty values. Guarding against its use ensures the expected operation.
     */
    error ERC7401IdZeroForbidden();

    /**
     * @dev Attempting to interact with an end-user account when a contract account is expected.
     */
    error ERC7401IsNotContract();

    /**
     * @dev Attempting to burn a total number of recursive children higher than the maximum set.
     * @param childContract Address of the collection smart contract in which the maximum number of recursive burns was reached.
     * @param childId ID of the child token at which the maximum number of recursive burns was reached.
     */
    error ERC7401MaxRecursiveBurnsReached(
        address childContract,
        uint256 childId
    );

    /**
     * @dev Attempting to nest a child over the nestable limit (current limit is 100 levels of nesting).
     */
    error ERC7401NestableTooDeep();

    /**
     * @dev Attempting to nest the token to own descendant, which would create a loop and leave the looped tokens in limbo.
     */
    error ERC7401NestableTransferToDescendant();

    /**
     * @dev Attempting to nest the token into itself.
     */
    error ERC7401NestableTransferToSelf();

    /**
     * @dev Attempting to interact with a token without being its owner or having been granted permission by the owner to do so.
     * When a token is nested, only the direct owner (NFT parent) can manage it. Approved addresses are not allowed to manage it, in order to ensure the expected behavior.
     */
    error ERC7401NotApprovedOrDirectOwner();

    /**
     * @dev Attempting to accept or transfer a child which does not match the one at the specified index.
     */
    error ERC7401UnexpectedChildId();

    /**
     * @dev Attempting to use an invalid ERC7401 contract.
     */
    error ERC7401IsNotAnERC7401Contract();

    /**
     * @dev Attempting to use an invalid child address.
     * @param childAddress Address of the invalid child.
     */
    error ERC7401DInvalidChildAddress(address childAddress);

    /**
     * @dev Attempting to use an invalid parent address.
     * @param parentAddress Address of the invalid parent.
     */
    error ERC7401DInvalidParentAddress(address parentAddress);

    /**
     * @dev Attempting to use a function that is not supported.
     */
    error ERC7401DFunctionNotSupported();

    /**
     * @dev Attempting to add a child address that already exists.
     * @param childAddress Address of the child that already exists.
     */
    error ERC7401DChildAddressAlreadyExists(address childAddress);

    /**
     * @dev Attempting to add a parent address that already exists.
     * @param parentAddress Address of the parent that already exists.
     */
    error ERC7401DParentAddressAlreadyExists(address parentAddress);

    /**
     * @dev Attempting to remove a child address that does not exist.
     * @param childAddress Address of the child that does not exist.
     */
    error ERC7401DChildAddressNotFound(address childAddress);

    /**
     * @dev Attempting to remove a parent address that does not exist.
     * @param parentAddress Address of the parent that does not exist.
     */
    error ERC7401DParentAddressNotFound(address parentAddress);
}
