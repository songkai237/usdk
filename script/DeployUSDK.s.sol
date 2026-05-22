// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {USDK} from "../src/USDK.sol";
import {USDKEngine} from "../src/USDKEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployUSDK is Script {

    HelperConfig.NetworkConfig public config;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    uint256[] public liquidationThresholds;
    address public owner = makeAddr("owner");


    function run() public returns (USDK, USDKEngine, HelperConfig.NetworkConfig memory) {

        HelperConfig hc = new HelperConfig();
        config = hc.getActiveNetworkConfig();

        tokenAddresses.push(config.weth);
        tokenAddresses.push(config.wbtc);
        priceFeedAddresses.push(config.wethUsdPriceFeed);
        priceFeedAddresses.push(config.wbtcUsdPriceFeed);

        vm.startBroadcast();
        USDK usdk = new USDK("USDK", "USDK", owner);
        liquidationThresholds.push(8000);
        liquidationThresholds.push(7000);
        USDKEngine engine = new USDKEngine(address(usdk), tokenAddresses, priceFeedAddresses, liquidationThresholds);
        
        vm.stopBroadcast();

        vm.prank(owner);
        usdk.transferOwnership(address(engine));

        return (usdk, engine, config);
    }
}