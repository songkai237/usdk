// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDK} from "../../src/USDK.sol";
import {MockAddress} from "../mock/MockAddress.t.sol";

contract TokenHandler is Test, MockAddress {
    USDK public usdk;

    string public name = "USDK Token";
    string public symbol = "USDK";
    address public owner = makeAddr("owner");

    uint256 public ghostMinted;
    uint256 public ghostBurned;

    constructor(USDK _usdk) {
        usdk = _usdk;
    }

    function totalSupply() public returns (uint256) {
        return usdk.totalSupply();
    }

    function allBalances() public returns (uint256) {
        uint256 sum;
        uint256 addressCount = addresses.length;
        for (uint256 i; i < addressCount; i++) {
            sum += usdk.balanceOf(addresses[i]);
        }
        return sum;
    }

    function mint(uint256 _userIdx, uint256 _value) public {
        _userIdx = bound(_userIdx, 0, addresses.length - 1);
        _value = bound(_value, 0, 1000 ether);
        vm.prank(owner);
        usdk.mint(addresses[_userIdx], _value);
        ghostMinted += _value;
    }

    function burn(uint256 _userIdx, uint256 _value) public {
        _userIdx = bound(_userIdx, 0, addresses.length - 1);
        //        _value = bound(_value, 0, usdk.balanceOf(addresses[_userIdx]));
        _value = bound(_value, 0, _value); // allow revert happens
        vm.prank(owner);
        ghostBurned += _value;
        usdk.burn(_value);
    }

    function transfer(uint256 _fromUserIdx, uint256 _toUserIdx, uint256 _value) public {
        _fromUserIdx = bound(_fromUserIdx, 0, addresses.length - 1);
        _toUserIdx = bound(_toUserIdx, 0, addresses.length - 1);

        address _from = addresses[_fromUserIdx];
        address _to = addresses[_toUserIdx];

        //        _value = bound(_value, 0, usdk.balanceOf(_from));
        _value = bound(_value, 0, _value); // allow revert happens

        vm.prank(_from);
        usdk.transfer(_to, _value);
    }

    function approveAndTransferFrom(
        uint256 _spenderIdx,
        uint256 _fromUserIdx,
        uint256 _toUserIdx,
        uint256 _approveValue,
        uint256 _transferValue
    ) public {
        _spenderIdx = bound(_spenderIdx, 0, addresses.length - 1);
        _fromUserIdx = bound(_fromUserIdx, 0, addresses.length - 1);
        _toUserIdx = bound(_toUserIdx, 0, addresses.length - 1);

        address _spender = addresses[_spenderIdx];
        address _from = addresses[_fromUserIdx];
        address _to = addresses[_toUserIdx];

        vm.prank(_from);
        usdk.approve(_spender, _approveValue);

        uint256 balance = usdk.balanceOf(_from);

        _transferValue = bound(_transferValue, 0, _getSmallerNumber(_approveValue, balance));

        vm.prank(_spender);
        usdk.transferFrom(_from, _to, _transferValue);
    }

    function _getSmallerNumber(uint256 _num1, uint256 _num2) private pure returns (uint256) {
        if (_num1 < _num2) {
            return _num1;
        }
        return _num2;
    }
}
