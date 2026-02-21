// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./interface/IERC20.sol";

/*
 * @title A stable token implements ERC20 Standard
 * @author SongKai
 */
contract USDK is IERC20 {
    // Type

/**********************************************************/
/*                    State variables                     */
/**********************************************************/

    address immutable private i_owner;
    string private s_name;
    string private s_symbol;

    uint256 private s_totalSupply;
    mapping(address account => uint256) private s_balances;
    mapping(address account => mapping(address spender => uint256)) private s_allowances;

/**********************************************************/
/*                         Errors                         */
/**********************************************************/

    error USDK__ZeroAddress();
    error USDK__InsufficientBalance();
    error USDK__InsufficientAllowance();
    error USDK_InvalidOwner();

/**********************************************************/
/*                       Modifiers                        */
/**********************************************************/

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert USDK_InvalidOwner();
        }
        _;
    }

/**********************************************************/
/*                      Constructor                       */
/**********************************************************/

    constructor(string memory _name, string memory _symbol, address _owner){
        if (_owner == address(0)) {
            revert USDK__ZeroAddress();
        }
        s_name = _name;
        s_symbol = _symbol;
        i_owner = _owner;
    }

/**********************************************************/
/*                        External                        */
/**********************************************************/

    function mint(address _to, uint256 _value) external onlyOwner {
        if (_to == address(0)) {
            revert USDK__ZeroAddress();
        }

        s_totalSupply += _value;
        s_balances[_to] += _value;

        emit Transfer(address(0), _to, _value);
    }

    function burn(uint256 _value) external onlyOwner {
        if (s_balances[msg.sender] < _value) {
            revert USDK__InsufficientBalance();
        }
        s_balances[msg.sender] -= _value;
        s_totalSupply -= _value;

        emit Transfer(msg.sender, address(0), _value);
    }

/**********************************************************/
/*                     External view                      */
/**********************************************************/

    function owner() external view returns (address) {
        return i_owner;
    }

    // external pure

/**********************************************************/
/*                         Public                         */
/**********************************************************/

    function name() public view returns (string memory) {
        return s_name;
    }

    function symbol() public view returns (string memory) {
        return s_symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return s_totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return s_balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 currentAllowance = s_allowances[_from][msg.sender];
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < _value) {
                revert USDK__InsufficientAllowance();
            }
            s_allowances[_from][msg.sender] -= _value;
        }

        _transfer(_from, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (_spender == address(0)) {
            revert USDK__ZeroAddress();
        }

        s_allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return s_allowances[_owner][_spender];
    }

/**********************************************************/
/*                        Internal                        */
/**********************************************************/

    function _transfer(address _from, address _to, uint256 _value) internal {
        if (_from == address(0)) {
            revert USDK__ZeroAddress();
        }
        if (_to == address(0)) {
            revert USDK__ZeroAddress();
        }
        if (s_balances[_from] < _value) {
            revert USDK__InsufficientBalance();
        }

        s_balances[_from] -= _value;
        s_balances[_to] += _value;

        emit Transfer(_from, _to, _value);
    }

    // private
}
