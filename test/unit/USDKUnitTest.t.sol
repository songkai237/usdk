// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDK} from "../../src/USDK.sol";

contract USDKUnitTest is Test {
    USDK public usdk;

    uint256 constant public AMOUNT_TO_MINT = 10;

    address public owner = makeAddr("owner");
    string public name = "USDK Token";
    string public symbol = "USDK";

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public peter = makeAddr("peter");
    address public zeroAddress = address(0);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        usdk = new USDK(name, symbol, owner);
    }

/**********************************************************/
/*                       Modifiers                        */
/**********************************************************/
    modifier mintSomeToken {
        vm.startPrank(owner);
        usdk.mint(alice, AMOUNT_TO_MINT);
        usdk.mint(bob, AMOUNT_TO_MINT);
        vm.stopPrank();

        _;
    }

    modifier mintToAddress(address _to, uint256 _value) {
        vm.startPrank(owner);
        usdk.mint(_to, _value);
        _;
    }

/**********************************************************/
/*                       Init test                        */
/**********************************************************/
    function testInitializationCorrectly() public {
        assertEq(usdk.name(), name);
        assertEq(usdk.symbol(), symbol);
        assertEq(usdk.owner(), owner);
        assertEq(usdk.totalSupply(), 0);
        assertEq(usdk.decimals(), 18);
    }

    function testTransferInsufficientBalance() public mintSomeToken {
        vm.prank(alice);
        vm.expectRevert(USDK.USDK__InsufficientBalance.selector);
        usdk.transfer(bob, 1000);
    }

/**********************************************************/
/*                  Access control test                   */
/**********************************************************/
    function testMintAndBurn() public {
        // mint
        vm.expectEmit(true, true, false, true);
        emit Transfer(zeroAddress, alice, AMOUNT_TO_MINT);
        vm.startPrank(owner);
        usdk.mint(alice, AMOUNT_TO_MINT);
        vm.stopPrank();
        assertEq(usdk.balanceOf(alice), AMOUNT_TO_MINT);

        // burn
        uint256 amountToBurn = 1;
        vm.prank(alice);
        usdk.transfer(owner, amountToBurn);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, zeroAddress, amountToBurn);
        vm.startPrank(owner);
        usdk.burn(amountToBurn);
        vm.stopPrank();
        assertEq(usdk.balanceOf(alice), AMOUNT_TO_MINT - amountToBurn);

        // burn out  of balance
        uint256 outOfBalance = 1000;

        vm.expectRevert(USDK.USDK__InsufficientBalance.selector);
        vm.prank(owner);
        usdk.burn(outOfBalance);
    }

    function testCanAnyoneMintOrBurn() public mintSomeToken {
        vm.expectRevert(USDK.USDK_InvalidOwner.selector);
        vm.prank(alice);
        usdk.mint(alice, 1);

        vm.expectRevert(USDK.USDK_InvalidOwner.selector);
        vm.prank(alice);
        usdk.burn(1);
    }

/**********************************************************/
/*                   Zero address test                    */
/**********************************************************/
    function testDeployWithZeroAddressOwner() public {
        vm.expectRevert(USDK.USDK__ZeroAddress.selector);
        USDK tmp = new USDK(name, symbol, zeroAddress);
    }

    function testZeroAddress() public mintSomeToken {
        // mint and burn
        vm.startPrank(owner);
        vm.expectRevert(USDK.USDK__ZeroAddress.selector);
        usdk.mint(zeroAddress, AMOUNT_TO_MINT);
        vm.stopPrank();

        // transfer and approve
        vm.startPrank(alice);
        vm.expectRevert(USDK.USDK__ZeroAddress.selector);
        usdk.transfer(zeroAddress, 1);
        vm.expectRevert(USDK.USDK__ZeroAddress.selector);
        usdk.approve(zeroAddress, 1);
        vm.stopPrank();

        // transferFrom
        vm.prank(bob);
        usdk.approve(alice, 1);
        vm.prank(alice);
        vm.expectRevert(USDK.USDK__ZeroAddress.selector);
        usdk.transferFrom(bob, zeroAddress, 1);
    }

/**********************************************************/
/*                    Allowance test                     */
/**********************************************************/
    function testAllowanceCorrect() public mintSomeToken {
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 2);
        vm.prank(alice);
        usdk.approve(bob, 2);
        vm.assertEq(usdk.balanceOf(alice), 10);
        vm.startPrank(bob);
        vm.assertEq(usdk.allowance(alice, bob), 2);
        vm.expectRevert(USDK.USDK__InsufficientAllowance.selector);
        usdk.transferFrom(alice, peter, 100);
        usdk.transferFrom(alice, peter, 1);
        assertEq(usdk.allowance(alice, bob), 1);
        assertEq(usdk.balanceOf(alice), AMOUNT_TO_MINT - 1);
        assertEq(usdk.balanceOf(bob), AMOUNT_TO_MINT);
        assertEq(usdk.balanceOf(peter), 1);
        usdk.transferFrom(alice, bob, 1);
        assertEq(usdk.balanceOf(alice), AMOUNT_TO_MINT - 2);
        assertEq(usdk.balanceOf(bob), AMOUNT_TO_MINT + 1);
        assertEq(usdk.allowance(alice, bob), 0);
        vm.stopPrank();
    }

/**********************************************************/
/*                     Stateless fuzz                     */
/**********************************************************/
    function testFuzzTransfer(uint256 _amountToTransfer) public mintToAddress(alice, 10 ether) {
        _amountToTransfer = bound(_amountToTransfer, 0, 10 ether);

        uint256 startTotalSupply = usdk.totalSupply();

        vm.startPrank(alice);
        usdk.transfer(bob, _amountToTransfer);
        vm.stopPrank();

        assertEq(usdk.balanceOf(alice), 10 ether - _amountToTransfer);
        assertEq(usdk.balanceOf(bob), _amountToTransfer);
        assertEq(usdk.totalSupply(), startTotalSupply);
    }
}