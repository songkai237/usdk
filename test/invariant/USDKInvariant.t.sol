// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDK} from "../../src/USDK.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "./Handler.t.sol";

contract USDKInvariantTest is StdInvariant, Test {
    Handler public handler;
    USDK public usdk;

    address public owner = makeAddr("owner");
    string public name = "USDK Token";
    string public symbol = "USDK";

    function setUp() public {
        usdk = new USDK(name, symbol, owner);
        handler = new Handler(usdk);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.mint.selector;
        selectors[1] = handler.burn.selector;
        selectors[2] = handler.transfer.selector;
        selectors[3] = handler.approveAndTransferFrom.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_sumOfBalancesEqualsTotalSupply() public {
        assertEq(handler.allBalances(), handler.totalSupply());
        assertEq(handler.totalSupply(), handler.ghostMinted() - handler.ghostBurned());
    }
}