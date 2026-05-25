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

    function run() public returns (USDK, USDKEngine, HelperConfig.NetworkConfig memory) {
        _loadConfig();

        vm.startBroadcast(config.deployerKey);
        address deployer = vm.addr(config.deployerKey);
        (USDK usdk, USDKEngine engine) = _deployContracts(deployer);
        vm.stopBroadcast();

        return (usdk, engine, config);
    }

    /// @dev 供单元/不变量测试使用，不广播链上交易
    function deploy() public returns (USDK, USDKEngine, HelperConfig.NetworkConfig memory) {
        _loadConfig();

        address testOwner = makeAddr("owner");
        vm.startPrank(testOwner);
        (USDK usdk, USDKEngine engine) = _deployContracts(testOwner);
        vm.stopPrank();

        return (usdk, engine, config);
    }

    function _loadConfig() internal {
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
    }

    function _deployContracts(address owner) private returns (USDK usdk, USDKEngine engine) {
        usdk = new USDK("USDK", "USDK", owner);
        engine = new USDKEngine(address(usdk), tokenAddresses, priceFeedAddresses, liquidationThresholds);
        usdk.transferOwnership(address(engine));
    }
}
