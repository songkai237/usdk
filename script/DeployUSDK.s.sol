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
        vm.startBroadcast(owner);
        (USDK usdk, USDKEngine engine, HelperConfig.NetworkConfig memory networkConfig) = deploy();
        vm.stopBroadcast();
        return (usdk, engine, networkConfig);
    }

    function deploy() public returns (USDK, USDKEngine, HelperConfig.NetworkConfig memory) {
        HelperConfig hc = new HelperConfig();
        config = hc.getActiveNetworkConfig();

        delete tokenAddresses;
        delete priceFeedAddresses;
        delete liquidationThresholds;

        tokenAddresses.push(config.weth);
        tokenAddresses.push(config.wbtc);
        priceFeedAddresses.push(config.wethUsdPriceFeed);
        priceFeedAddresses.push(config.wbtcUsdPriceFeed);
        liquidationThresholds.push(8000);
        liquidationThresholds.push(7000);

        vm.startPrank(owner);
        USDK usdk = new USDK("USDK", "USDK", owner);
        USDKEngine engine = new USDKEngine(address(usdk), tokenAddresses, priceFeedAddresses, liquidationThresholds);
        usdk.transferOwnership(address(engine));
        vm.stopPrank();

        return (usdk, engine, config);
    }
}
