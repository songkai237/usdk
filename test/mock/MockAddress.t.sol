// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

contract MockAddress is Test {
    address[] public addresses;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public peter = makeAddr("peter");
    address public kate = makeAddr("kate");
    address public lisa = makeAddr("lisa");
    address public kevin = makeAddr("kevin");
    address public steve = makeAddr("steve");

    constructor() {
        addresses.push(alice);
        addresses.push(bob);
        addresses.push(peter);
        addresses.push(kate);
        addresses.push(lisa);
        addresses.push(kevin);
        addresses.push(steve);
    }
}
