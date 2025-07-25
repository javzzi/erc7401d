// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC7401} from "./IERC7401.sol";
import {IERC7401D} from "./IERC7401D.sol";
import {IERC7401DErrors} from "./IERC7401DErrors.sol";

/**
 * @title ERC7401D
 *
 * @dev Custom implementation of [ERC-7401](https://eips.ethereum.org/EIPS/eip-7401) for whitelist-based nestable NFTs.
 * This contract implements a custom version with the following differences:
 *      - Contract whitelisting: Only registered parent/child contracts can interact.
 *      - Direct nesting: Removes the propose-commit pattern for simplified user experience.
 *      - No pending children: All accepted children are immediately active.
 *
 * As a result, functions related to the propose-commit pattern and pending children
 * (`acceptChild`, `rejectAllChildren`, `pendingChildrenOf`, and `pendingChildOf`) are not supported.
 *
 * @author Javzzi with Doodles
 * @author Modified from RMRKNestable by RMRK team (https://github.com/rmrk-team/evm/blob/master/contracts/RMRK/nestable/RMRKNestable.sol)
 */
abstract contract ERC7401D is Context, IERC165, IERC721, IERC721Metadata, IERC7401D, IERC7401DErrors {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant _MAX_LEVELS_TO_CHECK_FOR_INHERITANCE_LOOP = 100;

    string private _name;
    string private _symbol;
    // Set of child contract addresses that can be nested into this contract
    EnumerableSet.AddressSet private _childAddresses;
    // Set of parent contract addresses that this contract can be nested into
    EnumerableSet.AddressSet private _parentAddresses;
    // Mapping owner address to token count
    mapping(address => uint256) private _balances;
    // Mapping from token ID to approver address to approved address
    // The approver is necessary so approvals are invalidated for nested children on transfer
    // WARNING: If a child NFT returns to a previous root owner, old permissions would be active again
    mapping(uint256 => mapping(address => address)) private _tokenApprovals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // Mapping from token ID to DirectOwner struct
    mapping(uint256 => DirectOwner) private _directOwners;
    // Mapping of parentId to child collections to array of tokenIds
    mapping(uint256 => mapping(address => uint256[])) private _children;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // -------------------------- MODIFIERS ----------------------------

    /**
     * @notice Used to verify that the caller is either the owner of the token or approved to manage it by its owner.
     * @dev If the caller is not the owner of the token or approved to manage it by its owner, the execution will be
     *  reverted.
     * @param tokenId ID of the token to check
     */
    function _onlyApprovedOrOwner(uint256 tokenId) internal view {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert ERC721NotApprovedOrOwner();
        }
    }

    /**
     * @notice Used to verify that the caller is either the owner of the token or approved to manage it by its owner.
     * @param tokenId ID of the token to check
     */
    modifier onlyApprovedOrOwner(uint256 tokenId) {
        _onlyApprovedOrOwner(tokenId);
        _;
    }

    /**
     * @notice Used to verify that the caller is approved to manage the given token or it its direct owner.
     * @dev This does not delegate to ownerOf, which returns the root owner, but rater uses an owner from DirectOwner
     *  struct.
     * @dev The execution is reverted if the caller is not immediate owner or approved to manage the given token.
     * @dev Used for parent-scoped transfers.
     * @param tokenId ID of the token to check.
     */
    function _onlyApprovedOrDirectOwner(uint256 tokenId) internal view {
        if (!_isApprovedOrDirectOwner(_msgSender(), tokenId)) {
            revert ERC7401NotApprovedOrDirectOwner();
        }
    }

    /**
     * @notice Used to verify that the caller is approved to manage the given token or is its direct owner.
     * @param tokenId ID of the token to check
     */
    modifier onlyApprovedOrDirectOwner(uint256 tokenId) {
        _onlyApprovedOrDirectOwner(tokenId);
        _;
    }

    // ------------------------------- ERC721 ---------------------------------
    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC7401).interfaceId || interfaceId == type(IERC7401D).interfaceId;
    }

    /**
     * @notice Used to retrieve the number of tokens in `owner`'s account.
     * @param owner Address of the account being checked
     * @return The balance of the given account
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) revert ERC721AddressZeroIsNotaValidOwner();
        return _balances[owner];
    }

    ////////////////////////////////////////
    //              TRANSFERS
    ////////////////////////////////////////

    /**
     * @notice Transfers a given token from `from` to `to`.
     * @dev Requirements:
     *
     *  - `from` cannot be the zero address.
     *  - `to` cannot be the zero address.
     *  - `tokenId` token must be owned by `from`.
     *  - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * @dev Emits a {Transfer} event.
     * @param from Address from which to transfer the token from
     * @param to Address to which to transfer the token to
     * @param tokenId ID of the token to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        virtual
        onlyApprovedOrDirectOwner(tokenId)
    {
        _transfer(from, to, tokenId, "");
    }

    /**
     * @notice Used to safely transfer a given token token from `from` to `to`.
     * @dev Requirements:
     *
     *  - `from` cannot be the zero address.
     *  - `to` cannot be the zero address.
     *  - `tokenId` token must exist and be owned by `from`.
     *  - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *  - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * @dev Emits a {Transfer} event.
     * @param from Address to transfer the tokens from
     * @param to Address to transfer the tokens to
     * @param tokenId ID of the token to transfer
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @notice Used to safely transfer a given token token from `from` to `to`.
     * @dev Requirements:
     *
     *  - `from` cannot be the zero address.
     *  - `to` cannot be the zero address.
     *  - `tokenId` token must exist and be owned by `from`.
     *  - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *  - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * @dev Emits a {Transfer} event.
     * @param from Address to transfer the tokens from
     * @param to Address to transfer the tokens to
     * @param tokenId ID of the token to transfer
     * @param data Additional data without a specified format to be sent along with the token transaction
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        onlyApprovedOrDirectOwner(tokenId)
    {
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @inheritdoc IERC7401
     */
    function nestTransferFrom(address from, address to, uint256 tokenId, uint256 destinationId, bytes memory data)
        public
        virtual
        onlyApprovedOrDirectOwner(tokenId)
    {
        _nestTransfer(from, to, tokenId, destinationId, data);
    }

    /**
     * @notice Used to safely transfer the token form `from` to `to`.
     * @dev The function checks that contract recipients are aware of the ERC721 protocol to prevent tokens from being
     *  forever locked.
     * @dev This internal function is equivalent to {safeTransferFrom}, and can be used to e.g. implement alternative
     *  mechanisms to perform token transfer, such as signature-based.
     * @dev Requirements:
     *
     *  - `from` cannot be the zero address.
     *  - `to` cannot be the zero address.
     *  - `tokenId` token must exist and be owned by `from`.
     *  - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * @dev Emits a {Transfer} event.
     * @param from Address of the account currently owning the given token
     * @param to Address to transfer the token to
     * @param tokenId ID of the token to transfer
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId, data);
        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert ERC721TransferToNonReceiverImplementer();
        }
    }

    /**
     * @notice Used to transfer the token from `from` to `to`.
     * @dev As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     * @dev Requirements:
     *
     *  - `to` cannot be the zero address.
     *  - `tokenId` token must be owned by `from`.
     * @dev Emits a {Transfer} event.
     * @param from Address of the account currently owning the given token
     * @param to Address to transfer the token to
     * @param tokenId ID of the token to transfer
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function _transfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        (address immediateOwner, uint256 parentId,) = directOwnerOf(tokenId);
        if (immediateOwner != from) revert ERC721TransferFromIncorrectOwner();
        if (to == address(0)) revert ERC721TransferToTheZeroAddress();

        _beforeTokenTransfer(from, to, tokenId);
        _beforeNestedTokenTransfer(from, to, parentId, 0, tokenId, data);

        _balances[from] -= 1;
        _updateOwnerAndClearApprovals(tokenId, 0, to);
        _balances[to] += 1;

        emit Transfer(from, to, tokenId);
        emit NestTransfer(from, to, parentId, 0, tokenId);

        _afterTokenTransfer(from, to, tokenId);
        _afterNestedTokenTransfer(from, to, parentId, 0, tokenId, data);
    }

    /**
     * @notice Used to transfer a token into another token.
     * @dev Attempting to nest a token into `0x0` address will result in reverted transaction.
     * @dev Attempting to nest a token into itself will result in reverted transaction.
     * @param from Address of the account currently owning the given token
     * @param to Address of the receiving token's collection smart contract
     * @param tokenId ID of the token to transfer
     * @param destinationId ID of the token receiving the given token
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _nestTransfer(address from, address to, uint256 tokenId, uint256 destinationId, bytes memory data)
        internal
        virtual
    {
        (address immediateOwner, uint256 parentId,) = directOwnerOf(tokenId);
        if (immediateOwner != from) revert ERC721TransferFromIncorrectOwner();
        if (to == address(this) && tokenId == destinationId) {
            revert ERC7401NestableTransferToSelf();
        }
        _checkDestination(to);
        _checkForInheritanceLoop(tokenId, to, destinationId);

        _beforeTokenTransfer(from, to, tokenId);
        _beforeNestedTokenTransfer(immediateOwner, to, parentId, destinationId, tokenId, data);

        _balances[from] -= 1;
        _updateOwnerAndClearApprovals(tokenId, destinationId, to);
        _balances[to] += 1;

        // Sending to NFT:
        _sendToNFT(immediateOwner, to, parentId, destinationId, tokenId, data);
    }

    /**
     * @notice Used to send a token to another token.
     * @dev If the token being sent is currently owned by an externally owned account, the `parentId` should equal `0`.
     * @dev Emits {Transfer} event.
     * @dev Emits {NestTransfer} event.
     * @param from Address from which the token is being sent
     * @param to Address of the collection smart contract of the token to receive the given token
     * @param parentId ID of the current parent token of the token being sent
     * @param destinationId ID of the tokento receive the token being sent
     * @param tokenId ID of the token being sent
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _sendToNFT(
        address from,
        address to,
        uint256 parentId,
        uint256 destinationId,
        uint256 tokenId,
        bytes memory data
    ) private {
        IERC7401 destContract = IERC7401(to);
        destContract.addChild(destinationId, tokenId, data);

        emit Transfer(from, to, tokenId);
        emit NestTransfer(from, to, parentId, destinationId, tokenId);

        _afterTokenTransfer(from, to, tokenId);
        _afterNestedTokenTransfer(from, to, parentId, destinationId, tokenId, data);
    }

    /**
     * @notice Used to check if nesting a given token into a specified token would create an inheritance loop.
     * @dev If a loop would occur, the tokens would be unmanageable, so the execution is reverted if one is detected.
     * @dev The check for inheritance loop is bounded to guard against too much gas being consumed.
     * @param currentId ID of the token that would be nested
     * @param targetContract Address of the collection smart contract of the token into which the given token would be
     *  nested
     * @param targetId ID of the token into which the given token would be nested
     */
    function _checkForInheritanceLoop(uint256 currentId, address targetContract, uint256 targetId) private view {
        for (uint256 i; i < _MAX_LEVELS_TO_CHECK_FOR_INHERITANCE_LOOP; i++) {
            (address nextOwner, uint256 nextOwnerTokenId, bool isNft) = IERC7401(targetContract).directOwnerOf(targetId);
            // If there's a final address, we're good. There's no loop.
            if (!isNft) {
                return;
            }
            // If the current nft is an ancestor at some point, there is an inheritance loop
            if (nextOwner == address(this) && nextOwnerTokenId == currentId) {
                revert ERC7401NestableTransferToDescendant();
            }
            // We reuse the parameters to save some contract size
            targetContract = nextOwner;
            targetId = nextOwnerTokenId;
        }
        revert ERC7401NestableTooDeep();
    }

    ////////////////////////////////////////
    //              MINTING
    ////////////////////////////////////////

    /**
     * @notice Used to safely mint the token to the specified address while passing the additional data to contract
     *  recipients.
     * @param to Address to which to mint the token
     * @param tokenId ID of the token to mint
     * @param data Additional data to send with the tokens
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId, data);
        if (!_checkOnERC721Received(address(0), to, tokenId, data)) {
            revert ERC721TransferToNonReceiverImplementer();
        }
    }

    /**
     * @notice Used to mint a specified token to a given address.
     * @dev WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible.
     * @dev Requirements:
     *
     *  - `tokenId` must not exist.
     *  - `to` cannot be the zero address.
     * @dev Emits a {Transfer} event.
     * @dev Emits a {NestTransfer} event.
     * @param to Address to mint the token to
     * @param tokenId ID of the token to mint
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function _mint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _innerMint(to, tokenId, 0, data);

        emit Transfer(address(0), to, tokenId);
        emit NestTransfer(address(0), to, 0, 0, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
        _afterNestedTokenTransfer(address(0), to, 0, 0, tokenId, data);
    }

    /**
     * @notice Used to mint a child token to a given parent token.
     * @param to Address of the collection smart contract of the token into which to mint the child token
     * @param tokenId ID of the token to mint
     * @param destinationId ID of the token into which to mint the new child token
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _nestMint(address to, uint256 tokenId, uint256 destinationId, bytes memory data) internal virtual {
        _checkDestination(to);
        _innerMint(to, tokenId, destinationId, data);
        _sendToNFT(address(0), to, 0, destinationId, tokenId, data);
    }

    /**
     * @notice Used to mint a child token into a given parent token.
     * @dev Requirements:
     *
     *  - `to` cannot be the zero address.
     *  - `tokenId` must not exist.
     *  - `tokenId` must not be `0`.
     * @param to Address of the collection smart contract of the token into which to mint the child token
     * @param tokenId ID of the token to mint
     * @param destinationId ID of the token into which to mint the new token
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function _innerMint(address to, uint256 tokenId, uint256 destinationId, bytes memory data) private {
        if (to == address(0)) revert ERC721MintToTheZeroAddress();
        if (_exists(tokenId)) revert ERC721TokenAlreadyMinted();
        if (tokenId == uint256(0)) revert ERC7401IdZeroForbidden();

        _beforeTokenTransfer(address(0), to, tokenId);
        _beforeNestedTokenTransfer(address(0), to, 0, destinationId, tokenId, data);

        _balances[to] += 1;
        _directOwners[tokenId] = DirectOwner({ownerAddress: to, tokenId: destinationId});
    }

    ////////////////////////////////////////
    //              Ownership
    ////////////////////////////////////////

    /**
     * @inheritdoc IERC7401
     */
    function ownerOf(uint256 tokenId) public view virtual override(IERC7401, IERC721) returns (address) {
        (address owner, uint256 ownerTokenId, bool isNft) = directOwnerOf(tokenId);
        if (isNft) {
            owner = IERC7401(owner).ownerOf(ownerTokenId);
        }
        return owner;
    }

    /**
     * @inheritdoc IERC7401
     */
    function directOwnerOf(uint256 tokenId)
        public
        view
        virtual
        returns (address owner_, uint256 parentId, bool isNFT)
    {
        DirectOwner memory owner = _directOwners[tokenId];
        if (owner.ownerAddress == address(0)) revert ERC721InvalidTokenId();

        owner_ = owner.ownerAddress;
        parentId = owner.tokenId;
        isNFT = owner.tokenId != 0;
    }

    ////////////////////////////////////////
    //              BURNING
    ////////////////////////////////////////

    /**
     * @notice Used to burn a given token.
     * @dev In case the token has any child tokens, the execution will be reverted.
     * @param tokenId ID of the token to burn
     */
    function burn(uint256 tokenId) public virtual {
        burn(tokenId, 0);
    }

    /**
     * @inheritdoc IERC7401
     */
    function burn(uint256 tokenId, uint256 maxChildrenBurns)
        public
        virtual
        onlyApprovedOrDirectOwner(tokenId)
        returns (uint256)
    {
        return _burn(tokenId, maxChildrenBurns);
    }

    /**
     * @notice Used to burn a token.
     * @dev When a token is burned, its children are recursively burned as well.
     * @dev The approvals are cleared when the token is burned.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @dev Emits a {Transfer} event.
     * @dev Emits a {NestTransfer} event.
     * @param tokenId ID of the token to burn
     * @param maxChildrenBurns Maximum children to recursively burn
     * @return The number of recursive burns it took to burn all of the children
     */
    function _burn(uint256 tokenId, uint256 maxChildrenBurns) internal virtual returns (uint256) {
        (address immediateOwner, uint256 parentId,) = directOwnerOf(tokenId);
        address rootOwner = ownerOf(tokenId);

        _beforeTokenTransfer(immediateOwner, address(0), tokenId);
        _beforeNestedTokenTransfer(immediateOwner, address(0), parentId, 0, tokenId, "");

        _balances[immediateOwner] -= 1;
        _approve(address(0), tokenId);
        _cleanApprovals(tokenId);

        uint256 totalChildBurns = _burnChildren(tokenId, maxChildrenBurns);

        // Can't remove before burning child since child will call back to get root owner
        delete _directOwners[tokenId];
        delete _tokenApprovals[tokenId][rootOwner];

        emit Transfer(immediateOwner, address(0), tokenId);
        emit NestTransfer(immediateOwner, address(0), parentId, 0, tokenId);

        _afterTokenTransfer(immediateOwner, address(0), tokenId);
        _afterNestedTokenTransfer(immediateOwner, address(0), parentId, 0, tokenId, "");

        return totalChildBurns;
    }

    /**
     * @notice Used to burn the children of a given token.
     * @dev This function is called recursively to burn nested children.
     * @dev If the number of child burns exceeds `maxChildrenBurns`, the function will revert.
     * @dev Requirements:
     *
     *  - `tokenId` must exist and have children.
     * @param tokenId ID of the parent token whose children are to be burned
     * @param maxChildrenBurns Maximum number of children to recursively burn
     * @return totalChildBurns The total number of children burned
     */
    function _burnChildren(uint256 tokenId, uint256 maxChildrenBurns) internal virtual returns (uint256) {
        uint256 totalChildBurns;

        address[] memory localChildAddresses = _childAddresses.values();
        uint256 childAddressesLength = localChildAddresses.length;

        for (uint256 i; i < childAddressesLength; i++) {
            address childAddress = localChildAddresses[i];
            uint256[] memory children = childrenOf(tokenId, childAddress);

            uint256 pendingRecursiveBurns;

            uint256 childrenLength = children.length;
            for (uint256 j; j < childrenLength; j++) {
                uint256 childId = children[j];

                if (totalChildBurns >= maxChildrenBurns) {
                    revert ERC7401MaxRecursiveBurnsReached(childAddress, childId);
                }
                delete _children[tokenId][childAddress];
                unchecked {
                    // At this point we know pendingRecursiveBurns must be at least 1
                    pendingRecursiveBurns = maxChildrenBurns - totalChildBurns;
                }
                // We substract one to the next level to count for the token being burned, then add it again on returns
                // This is to allow the behavior of 0 recursive burns meaning only the current token is deleted.
                totalChildBurns += IERC7401(childAddress).burn(childId, pendingRecursiveBurns - 1) + 1;
            }
        }

        return totalChildBurns;
    }

    ////////////////////////////////////////
    //              APPROVALS
    ////////////////////////////////////////

    /**
     * @notice Used to grant a one-time approval to manage one's token.
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * @dev The approval is cleared when the token is transferred.
     * @dev Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     * @dev Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     * @dev Emits an {Approval} event.
     * @param to Address receiving the approval
     * @param tokenId ID of the token for which the approval is being granted
     */
    function approve(address to, uint256 tokenId) public virtual {
        address owner = ownerOf(tokenId);
        if (to == owner) revert ERC721ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ERC721ApproveCallerIsNotOwnerNorApprovedForAll();
        }

        _approve(to, tokenId);
    }

    /**
     * @notice Used to retrieve the account approved to manage given token.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @param tokenId ID of the token to check for approval
     * @return Address of the account approved to manage the token
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId][ownerOf(tokenId)];
    }

    /**
     * @notice Used to approve or remove `operator` as an operator for the caller.
     * @dev Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     * @dev Requirements:
     *
     * - The `operator` cannot be the caller.
     * @dev Emits an {ApprovalForAll} event.
     * @param operator Address of the operator being managed
     * @param approved A boolean value signifying whether the approval is being granted (`true`) or (`revoked`)
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        if (_msgSender() == operator) revert ERC721ApproveToCaller();
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @notice Used to check if the given address is allowed to manage the tokens of the specified address.
     * @param owner Address of the owner of the tokens
     * @param operator Address being checked for approval
     * @return A boolean value signifying whether the *operator* is allowed to manage the tokens of the *owner* (`true`)
     *  or not (`false`)
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @notice Used to grant an approval to manage a given token.
     * @dev Emits an {Approval} event.
     * @param to Address to which the approval is being granted
     * @param tokenId ID of the token for which the approval is being granted
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        _tokenApprovals[tokenId][owner] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @notice Used to update the owner of the token and clear the approvals associated with the previous owner.
     * @dev The `destinationId` should equal `0` if the new owner is an externally owned account.
     * @param tokenId ID of the token being updated
     * @param destinationId ID of the token to receive the given token
     * @param to Address of account to receive the token
     */
    function _updateOwnerAndClearApprovals(uint256 tokenId, uint256 destinationId, address to) internal {
        _directOwners[tokenId] = DirectOwner({ownerAddress: to, tokenId: destinationId});

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _cleanApprovals(tokenId);
    }

    /**
     * @notice Used to remove approvals for the current owner of the given token.
     * @param tokenId ID of the token to clear the approvals for
     */
    function _cleanApprovals(uint256 tokenId) internal virtual {}

    ////////////////////////////////////////
    //              UTILS
    ////////////////////////////////////////

    /**
     * @notice Used to check whether the given account is allowed to manage the given token.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @param spender Address that is being checked for approval
     * @param tokenId ID of the token being checked
     * @return A boolean value indicating whether the `spender` is approved to manage the given token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @notice Used to check whether the account is approved to manage the token or its direct owner.
     * @param spender Address that is being checked for approval or direct ownership
     * @param tokenId ID of the token being checked
     * @return A boolean value indicating whether the `spender` is approved to manage the given token or its
     *  direct owner
     */
    function _isApprovedOrDirectOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        (address owner, uint256 parentId,) = directOwnerOf(tokenId);
        // When the parent is an NFT, only it can do operations
        if (parentId != 0) {
            return (spender == owner);
        }
        // Otherwise, the owner or approved address can
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @notice Used to enforce that the given token has been minted.
     * @dev Reverts if the `tokenId` has not been minted yet.
     * @dev The validation checks whether the owner of a given token is a `0x0` address and considers it not minted if
     *  it is. This means that both tokens that haven't been minted yet as well as the ones that have already been
     *  burned will cause the transaction to be reverted.
     * @param tokenId ID of the token to check
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        if (!_exists(tokenId)) revert ERC721InvalidTokenId();
    }

    /**
     * @notice Used to check whether the given token exists.
     * @dev Tokens start existing when they are minted (`_mint`) and stop existing when they are burned (`_burn`).
     * @param tokenId ID of the token being checked
     * @return A boolean value signifying whether the token exists
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _directOwners[tokenId].ownerAddress != address(0);
    }

    /**
     * @notice Used to invoke {IERC721Receiver-onERC721Received} on a target address.
     * @dev The call is not executed if the target address is not a contract.
     * @param from Address representing the previous owner of the given token
     * @param to Yarget address that will receive the tokens
     * @param tokenId ID of the token to be transferred
     * @param data Optional data to send along with the call
     * @return valid Boolean value signifying whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data)
        private
        returns (bool)
    {
        if (to.code.length != 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == uint256(0)) {
                    revert ERC721TransferToNonReceiverImplementer();
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    ////////////////////////////////////////
    //      CHILD MANAGEMENT PUBLIC
    ////////////////////////////////////////

    /**
     * @inheritdoc IERC7401
     */
    function addChild(uint256 parentId, uint256 childId, bytes memory data) public virtual {
        _requireMinted(parentId);

        address msgSender = _msgSender();

        if (!_childAddresses.contains(msgSender)) {
            revert ERC7401DInvalidChildAddress(msgSender);
        }

        _beforeAddChild(parentId, msgSender, childId, data);

        uint256[] storage childrenRef = _children[parentId][msgSender];

        childrenRef.push(childId);

        emit ChildAccepted(parentId, childrenRef.length - 1, msgSender, childId);

        _afterAddChild(parentId, msgSender, childId, data);
    }

    /**
     * @dev This function is not supported. ERC-7401D uses a direct nesting model and does not have a pending state
     * for children. Use {addChild} to directly nest a token.
     */
    function acceptChild(uint256, uint256, address, uint256) public virtual {
        revert ERC7401DFunctionNotSupported();
    }

    /**
     * @dev This function is not supported. ERC-7401D uses a direct nesting model and does not have a pending state
     * for children.
     */
    function rejectAllChildren(uint256, uint256) public virtual {
        revert ERC7401DFunctionNotSupported();
    }

    /**
     * @inheritdoc IERC7401
     */
    function transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bool,
        bytes memory data
    ) public virtual onlyApprovedOrOwner(tokenId) {
        _transferChild(tokenId, to, destinationId, childIndex, childAddress, childId, data);
    }

    /**
     * @notice Used to transfer a child token from a given parent token.
     * @dev When transferring a child token, the owner of the token is set to `to`, or is not updated in the event of
     *  `to` being the `0x0` address.
     * @dev Requirements:
     *
     *  - `tokenId` must exist.
     * @dev Emits {ChildTransferred} event.
     * @param tokenId ID of the parent token from which the child token is being transferred
     * @param to Address to which to transfer the token to
     * @param destinationId ID of the token to receive this child token (MUST be 0 if the destination is not a token)
     * @param childIndex Index of a token we are transferring, in the array it belongs to (can be either active array or
     *  pending array)
     * @param childAddress Address of the child token's collection smart contract.
     * @param childId ID of the child token in its own collection smart contract.
     * @param data Additional data with no specified format, sent in call to `_to`
     */
    function _transferChild(
        uint256 tokenId,
        address to,
        uint256 destinationId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) internal virtual {
        _checkExpectedChildId(tokenId, childAddress, childIndex, childId);

        _beforeTransferChild(tokenId, childIndex, childAddress, childId, data);

        _removeUint256ByIndex(_children[tokenId][childAddress], childIndex);

        if (to != address(0)) {
            if (destinationId == uint256(0)) {
                IERC721(childAddress).safeTransferFrom(address(this), to, childId, data);
            } else {
                // Destination is an NFT
                IERC7401(childAddress).nestTransferFrom(address(this), to, childId, destinationId, data);
            }
        }

        emit ChildTransferred(tokenId, childIndex, childAddress, childId, false, to == address(0));

        _afterTransferChild(tokenId, childIndex, childAddress, childId, data);
    }

    /**
     * @notice Used to check if the child token at a given index matches the expected child ID.
     * @dev This function is used as a safeguard to ensure that the correct child token is being transferred.
     * @dev Requirements:
     *
     *  - The child token at `childIndex` must exist.
     *  - The child token's ID must match the `expectedChildId`.
     * @dev Reverts with `ERC7401UnexpectedChildId` if the child ID doesn't match the expected ID.
     * @param tokenId ID of the parent token
     * @param childAddress Address of the child token's collection smart contract
     * @param childIndex Index of the child token in the parent token's children array
     * @param expectedChildId The expected ID of the child token
     */
    function _checkExpectedChildId(uint256 tokenId, address childAddress, uint256 childIndex, uint256 expectedChildId)
        private
        view
    {
        uint256 childIdByIndex = childOf(tokenId, childAddress, childIndex);
        if (childIdByIndex != expectedChildId) {
            revert ERC7401UnexpectedChildId();
        }
    }

    ////////////////////////////////////////
    //      CHILD MANAGEMENT GETTERS
    ////////////////////////////////////////

    /**
     * @inheritdoc IERC7401
     */
    function childrenOf(uint256 parentId) public view virtual returns (Child[] memory children) {
        address[] memory localChildAddresses = _childAddresses.values();
        uint256 childAddressesLength = localChildAddresses.length;

        uint256 totalChildren = 0;
        for (uint256 i; i < childAddressesLength; i++) {
            address childAddress = localChildAddresses[i];
            totalChildren += _children[parentId][childAddress].length;
        }

        children = new Child[](totalChildren);

        uint256 totalChildrenIndex;

        for (uint256 i; i < childAddressesLength; i++) {
            address childAddress = localChildAddresses[i];
            uint256[] memory childIds = _children[parentId][childAddress];
            uint256 childIdsLength = childIds.length;

            for (uint256 j; j < childIdsLength; j++) {
                children[totalChildrenIndex] = Child({tokenId: childIds[j], contractAddress: childAddress});

                unchecked {
                    ++totalChildrenIndex;
                }
            }
        }
    }

    /**
     * @inheritdoc IERC7401D
     */
    function childrenOf(uint256 parentId, address childAddress) public view virtual returns (uint256[] memory) {
        return _children[parentId][childAddress];
    }

    /**
     * @dev This function is not supported because ERC-7401D does not have a pending state for children.
     */
    function pendingChildrenOf(uint256) public view virtual returns (Child[] memory) {
        revert ERC7401DFunctionNotSupported();
    }

    /**
     * @inheritdoc IERC7401
     */
    function childOf(uint256 parentId, uint256 index) public view virtual returns (Child memory) {
        address[] memory localChildAddresses = _childAddresses.values();
        uint256 childAddressesLength = localChildAddresses.length;
        uint256 totalChildrenIndex;

        for (uint256 i; i < childAddressesLength; i++) {
            address childAddress = localChildAddresses[i];
            uint256[] memory children = _children[parentId][childAddress];
            uint256 childrenLength = children.length;

            if (totalChildrenIndex + childrenLength > index) {
                return Child({tokenId: children[index - totalChildrenIndex], contractAddress: childAddress});
            }

            totalChildrenIndex += childrenLength;
        }

        revert ERC7401ChildIndexOutOfRange();
    }

    /**
     * @inheritdoc IERC7401D
     */
    function childOf(uint256 parentId, address childAddress, uint256 index) public view virtual returns (uint256) {
        if (childrenOf(parentId, childAddress).length <= index) {
            revert ERC7401ChildIndexOutOfRange();
        }

        return _children[parentId][childAddress][index];
    }

    /**
     * @dev This function is not supported because ERC-7401D does not have a pending state for children.
     */
    function pendingChildOf(uint256, uint256) public view virtual returns (Child memory) {
        revert ERC7401DFunctionNotSupported();
    }

    /**
     * @notice Checks the destination is a parent address.
     * @dev The destination must be a parent address.
     * @param to Address of the destination
     */
    function _checkDestination(address to) internal view {
        if (!isParentAddress(to)) revert ERC7401DInvalidParentAddress(to);
    }

    ////////////////////////////////////////
    //      CONTRACTS MANAGEMENT
    ////////////////////////////////////////

    /**
     * @notice Used to add a child address to the collection.
     * @dev The child address must be a contract that implements the ERC7401 interface.
     * @param childAddress Address of the child contract to add
     */
    function _addChildAddress(address childAddress) internal virtual {
        if (childAddress.code.length == 0) revert ERC7401IsNotContract();
        if (!IERC165(childAddress).supportsInterface(type(IERC7401).interfaceId)) {
            revert ERC7401IsNotAnERC7401Contract();
        }

        if (!_childAddresses.add(childAddress)) {
            revert ERC7401DChildAddressAlreadyExists(childAddress);
        }

        emit ChildAddressAdded(childAddress);
    }

    /**
     * @notice Used to remove a child address from the collection.
     * @param childAddress Address of the child contract to remove
     */
    function _removeChildAddress(address childAddress) internal virtual {
        if (!_childAddresses.remove(childAddress)) {
            revert ERC7401DChildAddressNotFound(childAddress);
        }

        emit ChildAddressRemoved(childAddress);
    }

    /**
     * @notice Used to add a parent address to the collection.
     * @dev The parent address must be a contract that implements the ERC7401 interface.
     * @param parentAddress Address of the parent contract to add
     */
    function _addParentAddress(address parentAddress) internal virtual {
        if (parentAddress.code.length == 0) revert ERC7401IsNotContract();
        if (!IERC165(parentAddress).supportsInterface(type(IERC7401).interfaceId)) {
            revert ERC7401IsNotAnERC7401Contract();
        }

        if (!_parentAddresses.add(parentAddress)) {
            revert ERC7401DParentAddressAlreadyExists(parentAddress);
        }

        emit ParentAddressAdded(parentAddress);
    }

    /**
     * @notice Used to remove a parent address from the collection.
     * @param parentAddress Address of the parent contract to remove
     */
    function _removeParentAddress(address parentAddress) internal virtual {
        if (!_parentAddresses.remove(parentAddress)) {
            revert ERC7401DParentAddressNotFound(parentAddress);
        }

        emit ParentAddressRemoved(parentAddress);
    }

    /**
     * @inheritdoc IERC7401D
     */
    function isChildAddress(address childAddress) public view virtual returns (bool) {
        return _childAddresses.contains(childAddress);
    }

    /**
     * @inheritdoc IERC7401D
     */
    function isParentAddress(address parentAddress) public view virtual returns (bool) {
        return _parentAddresses.contains(parentAddress);
    }

    /**
     * @inheritdoc IERC7401D
     */
    function childAddresses() public view virtual returns (address[] memory) {
        return _childAddresses.values();
    }

    /**
     * @inheritdoc IERC7401D
     */
    function parentAddresses() public view virtual returns (address[] memory) {
        return _parentAddresses.values();
    }

    // HOOKS

    /**
     * @notice Hook that is called before any token transfer. This includes minting and burning.
     * @dev Calling conditions:
     *
     *  - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be transferred to `to`.
     *  - When `from` is zero, `tokenId` will be minted to `to`.
     *  - When `to` is zero, ``from``'s `tokenId` will be burned.
     *  - `from` and `to` are never zero at the same time.
     *
     *  To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param from Address from which the token is being transferred
     * @param to Address to which the token is being transferred
     * @param tokenId ID of the token being transferred
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @notice Hook that is called after any transfer of tokens. This includes minting and burning.
     * @dev Calling conditions:
     *
     *  - When `from` and `to` are both non-zero.
     *  - `from` and `to` are never zero at the same time.
     *
     *  To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param from Address from which the token has been transferred
     * @param to Address to which the token has been transferred
     * @param tokenId ID of the token that has been transferred
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    /**
     * @notice Hook that is called before nested token transfer.
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param from Address from which the token is being transferred
     * @param to Address to which the token is being transferred
     * @param fromTokenId ID of the token from which the given token is being transferred
     * @param toTokenId ID of the token to which the given token is being transferred
     * @param tokenId ID of the token being transferred
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _beforeNestedTokenTransfer(
        address from,
        address to,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {}

    /**
     * @notice Hook that is called after nested token transfer.
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param from Address from which the token was transferred
     * @param to Address to which the token was transferred
     * @param fromTokenId ID of the token from which the given token was transferred
     * @param toTokenId ID of the token to which the given token was transferred
     * @param tokenId ID of the token that was transferred
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _afterNestedTokenTransfer(
        address from,
        address to,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {}

    /**
     * @notice Hook that is called before a child is added to the pending tokens array of a given token.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param tokenId ID of the token that will receive a new pending child token
     * @param childAddress Address of the collection smart contract of the child token expected to be located at the
     *  specified index of the given parent token's pending children array
     * @param childId ID of the child token expected to be located at the specified index of the given parent token's
     *  pending children array
     * @param data Additional data with no specified format
     */
    function _beforeAddChild(uint256 tokenId, address childAddress, uint256 childId, bytes memory data)
        internal
        virtual
    {}

    /**
     * @notice Hook that is called after a child is added to the pending tokens array of a given token.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param tokenId ID of the token that has received a new pending child token
     * @param childAddress Address of the collection smart contract of the child token expected to be located at the
     *  specified index of the given parent token's pending children array
     * @param childId ID of the child token expected to be located at the specified index of the given parent token's
     *  pending children array
     * @param data Additional data with no specified format
     */
    function _afterAddChild(uint256 tokenId, address childAddress, uint256 childId, bytes memory data)
        internal
        virtual
    {}

    /**
     * @notice Hook that is called before a child is transferred from a given child token array of a given token.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param tokenId ID of the token that will transfer a child token
     * @param childIndex Index of the child token that will be transferred from the given parent token's children array
     * @param childAddress Address of the collection smart contract of the child token that is expected to be located
     *  at the specified index of the given parent token's children array
     * @param childId ID of the child token that is expected to be located at the specified index of the given parent
     *  token's children array
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _beforeTransferChild(
        uint256 tokenId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) internal virtual {}

    /**
     * @notice Hook that is called after a child is transferred from a given child token array of a given token.
     * @dev The Child struct consists of the following values:
     *  [
     *      tokenId,
     *      contractAddress
     *  ]
     * @dev To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     * @param tokenId ID of the token that has transferred a child token
     * @param childIndex Index of the child token that was transferred from the given parent token's children array
     * @param childAddress Address of the collection smart contract of the child token that was expected to be located
     *  at the specified index of the given parent token's children array
     * @param childId ID of the child token that was expected to be located at the specified index of the given parent
     *  token's children array
     * @param data Additional data with no specified format, sent in the addChild call
     */
    function _afterTransferChild(
        uint256 tokenId,
        uint256 childIndex,
        address childAddress,
        uint256 childId,
        bytes memory data
    ) internal virtual {}

    /**
     * @notice Used to retrieve the collection name.
     * @return Name of the collection
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @notice Used to retrieve the collection symbol.
     * @return Symbol of the collection
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    // HELPERS

    /**
     * @notice Used to remove a specified value form an array using its index within said array.
     * @dev The caller must ensure that the length of the array is valid compared to the index passed.
     * @param array An array of uint256 values
     * @param index An index of the uint256 value to remove in the accompanying array
     */
    function _removeUint256ByIndex(uint256[] storage array, uint256 index) private {
        array[index] = array[array.length - 1];
        array.pop();
    }
}
