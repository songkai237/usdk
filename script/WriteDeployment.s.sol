// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {DeployUSDK} from "./DeployUSDK.s.sol";
import {USDK} from "../src/USDK.sol";
import {USDKEngine} from "../src/USDKEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/// @notice Deploy contracts and write addresses to deployments/{chainId}.json
contract WriteDeployment is Script {
    function run() external {
        DeployUSDK deployer = new DeployUSDK();
        (USDK usdk, USDKEngine engine, HelperConfig.NetworkConfig memory cfg) = deployer.run();

        string memory path = string.concat("deployments/", vm.toString(block.chainid), ".json");
        string memory obj = "deployment";
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeString(obj, "rpcUrl", "http://127.0.0.1:8545");
        vm.serializeAddress(obj, "usdk", address(usdk));
        vm.serializeAddress(obj, "engine", address(engine));
        vm.serializeAddress(obj, "weth", cfg.weth);
        vm.serializeAddress(obj, "wbtc", cfg.wbtc);
        vm.serializeAddress(obj, "wethUsdPriceFeed", cfg.wethUsdPriceFeed);
        vm.serializeAddress(obj, "wbtcUsdPriceFeed", cfg.wbtcUsdPriceFeed);
        string memory json = vm.serializeAddress(obj, "engine", address(engine));

        vm.writeFile(path, json);
    }
}
