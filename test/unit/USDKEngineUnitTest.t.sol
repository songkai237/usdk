// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDKEngine} from "../../src/USDKEngine.sol";
import {USDK} from "../../src/USDK.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract USDKEngineUnitTest is Test {
    address public owner = makeAddr("owner");
    string public name = "USDK Token";
    string public symbol = "USDK";

    USDKEngine public engine;
    USDK public usdk;

    ERC20Mock public weth;
    ERC20Mock public wbtc;
    ERC20Mock public someToken;


    function setUp() public {
        // init ERC20 tokens
        weth = new ERC20Mock();
        wbtc = new ERC20Mock();
        someToken = new ERC20Mock();

        usdk = new USDK(name, symbol, owner);
        engine = new USDKEngine();
    }
}