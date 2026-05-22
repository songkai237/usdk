// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mock/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address weth;
        address wbtc;
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 4000e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getAnvilConfig();
        } else {
            revert();
        }
    }

    function getSepoliaConfig() private returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() private returns (NetworkConfig memory anvilNetworkConfig) {
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        ERC20Mock wethMock = new ERC20Mock("weth", "weth");
        ERC20Mock wbtcMock = new ERC20Mock("wbtc", "wbtc");
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}