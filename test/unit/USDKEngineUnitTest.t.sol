// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDKEngine} from "../../src/USDKEngine.sol";
import {USDK} from "../../src/USDK.sol";
import {DeployUSDK} from "../../script/DeployUSDK.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mock/ERC20Mock.sol";

contract USDKEngineUnitTest is Test {
    DeployUSDK public deployer;
    HelperConfig.NetworkConfig public config;
    USDKEngine public engine;
    USDK public usdk;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 public constant WETH_THRESHOLD = 8000;
    uint256 public constant WBTC_THRESHOLD = 7000;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant AMOUNT_TO_DEPOSIT = 100 ether;

    event Deposit(address indexed _account, address indexed _token, uint256 amount);
    event Redeem(address indexed _account, address indexed _token, uint256 amount);
    event Mint(address indexed _account, uint256 amount);
    event Burn(address indexed _account, uint256 amount);
    event Liquidate(address indexed _account, address indexed _liquidator, uint256 debtToCover);

    function setUp() public {
        deployer = new DeployUSDK();
        (usdk, engine, config) = deployer.run();
        weth = ERC20Mock(config.weth);
        wbtc = ERC20Mock(config.wbtc);

        ERC20Mock(weth).mint(alice, AMOUNT_TO_DEPOSIT);
    }

    function testInitializationCorrectly() public {
        assertEq(engine.getUsdkAddr(), address(usdk));

        (address wethPriceFeed, uint256 wethThreshold) = engine.getCollateralConfig(address(weth));
        (address wbtcPriceFeed, uint256 wbtcThreshold) = engine.getCollateralConfig(address(wbtc));
        assertEq(wethPriceFeed, config.wethUsdPriceFeed);
        assertEq(wbtcPriceFeed, config.wbtcUsdPriceFeed);
        assertEq(wethThreshold, WETH_THRESHOLD);
        assertEq(wbtcThreshold, WBTC_THRESHOLD);
    }

    function testDeposit() public {
        assertEq(weth.balanceOf(alice), AMOUNT_TO_DEPOSIT);
        
        vm.startPrank(alice);
        weth.approve(address(engine), AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit Deposit(alice, address(weth), AMOUNT_TO_DEPOSIT);
        engine.deposit(address(weth), AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
        assertEq(engine.getUserCollateral(alice, address(weth)), AMOUNT_TO_DEPOSIT);
    }
}