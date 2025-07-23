// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC7401DTestBase} from "./utils/ERC7401DTestBase.sol";
import {ERC165Mock} from "../src/mocks/ERC165Mock.sol";
import {IERC7401D} from "../src/IERC7401D.sol";

contract ManagementTest is ERC7401DTestBase {
    function test_ShouldAddChildContractCorrectly() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        assertTrue(erc7401dParent.isChildAddress(address(erc7401dChild1)));
    }

    function test_ShouldRemoveChildContractCorrectly() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));
        erc7401dParent.removeChildAddress(address(erc7401dChild1));
        assertFalse(erc7401dParent.isChildAddress(address(erc7401dChild1)));
    }

    function test_ShouldAddParentContractCorrectly() public {
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        assertTrue(erc7401dChild1.isParentAddress(address(erc7401dParent)));
    }

    function test_ShouldRemoveParentContractCorrectly() public {
        erc7401dChild1.addParentAddress(address(erc7401dParent));
        erc7401dChild1.removeParentAddress(address(erc7401dParent));
        assertFalse(erc7401dChild1.isParentAddress(address(erc7401dParent)));
    }

    function test_ShouldEmitChildAddressAddedEventWhenAddingChild() public {
        vm.expectEmit(true, false, false, false);
        emit IERC7401D.ChildAddressAdded(address(erc7401dChild1));
        erc7401dParent.addChildAddress(address(erc7401dChild1));
    }

    function test_ShouldEmitChildAddressRemovedEventWhenRemovingChild() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.expectEmit(true, false, false, false);
        emit IERC7401D.ChildAddressRemoved(address(erc7401dChild1));
        erc7401dParent.removeChildAddress(address(erc7401dChild1));
    }

    function test_ShouldEmitParentAddressAddedEventWhenAddingParent() public {
        vm.expectEmit(true, false, false, false);
        emit IERC7401D.ParentAddressAdded(address(erc7401dParent));
        erc7401dChild1.addParentAddress(address(erc7401dParent));
    }

    function test_ShouldEmitParentAddressRemovedEventWhenRemovingParent()
        public
    {
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        vm.expectEmit(true, false, false, false);
        emit IERC7401D.ParentAddressRemoved(address(erc7401dParent));
        erc7401dChild1.removeParentAddress(address(erc7401dParent));
    }

    function test_RevertWhen_AddingChildThatIsNotAContract() public {
        vm.expectRevert(ERC7401IsNotContract.selector);
        erc7401dParent.addChildAddress(other);
    }

    function test_RevertWhen_AddingParentThatIsNotAContract() public {
        vm.expectRevert(ERC7401IsNotContract.selector);
        erc7401dChild1.addParentAddress(other);
    }

    function test_RevertWhen_AddingChildThatDoesNotImplementERC7401() public {
        vm.expectRevert(ERC7401IsNotAnERC7401Contract.selector);
        erc7401dParent.addChildAddress(nonERC7401Contract);
    }

    function test_RevertWhen_AddingParentThatDoesNotImplementERC7401() public {
        vm.expectRevert(ERC7401IsNotAnERC7401Contract.selector);
        erc7401dChild1.addParentAddress(nonERC7401Contract);
    }

    function test_RevertWhen_AddingChildAddressThatAlreadyExists() public {
        erc7401dParent.addChildAddress(address(erc7401dChild1));

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DChildAddressAlreadyExists.selector,
                address(erc7401dChild1)
            )
        );
        erc7401dParent.addChildAddress(address(erc7401dChild1));
    }

    function test_RevertWhen_AddingParentAddressThatAlreadyExists() public {
        erc7401dChild1.addParentAddress(address(erc7401dParent));

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DParentAddressAlreadyExists.selector,
                address(erc7401dParent)
            )
        );
        erc7401dChild1.addParentAddress(address(erc7401dParent));
    }

    function test_RevertWhen_RemovingChildAddressThatDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DChildAddressNotFound.selector,
                address(erc7401dChild1)
            )
        );
        erc7401dParent.removeChildAddress(address(erc7401dChild1));
    }

    function test_RevertWhen_RemovingParentAddressThatDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7401DParentAddressNotFound.selector,
                address(erc7401dParent)
            )
        );
        erc7401dChild1.removeParentAddress(address(erc7401dParent));
    }
}
