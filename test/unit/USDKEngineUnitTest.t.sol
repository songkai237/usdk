// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDKEngine} from "../../src/USDKEngine.sol";
import {USDK} from "../../src/USDK.sol";
import {DeployUSDK} from "../../script/DeployUSDK.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mock/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mock/MockV3Aggregator.sol";

contract USDKEngineUnitTest is Test {
    DeployUSDK public deployer;
    HelperConfig.NetworkConfig public config;
    USDKEngine public engine;
    USDK public usdk;

    ERC20Mock public weth;
    ERC20Mock public wbtc;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;

    uint256 public constant WETH_THRESHOLD = 8000;
    uint256 public constant WBTC_THRESHOLD = 7000;
    uint256 public constant ETH_PRICE = 2000e18;
    uint256 public constant BTC_PRICE = 4000e18;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 1000;
    uint256 public constant LIQUIDATION_PRECISION = 1e4;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public randomToken = makeAddr("randomToken");

    uint256 public constant AMOUNT_TO_DEPOSIT = 100 ether;
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;

    event Deposit(address indexed _account, address indexed _token, uint256 amount);
    event Redeem(address indexed _account, address indexed _token, uint256 amount);
    event Mint(address indexed _account, uint256 amount);
    event Burn(address indexed _account, uint256 amount);
    event Liquidate(address indexed _account, address indexed _liquidator, uint256 debtToCover);

    modifier depositCollateral() {
        _deposit(alice, address(weth), AMOUNT_TO_DEPOSIT);
        _;
    }

    function setUp() public {
        deployer = new DeployUSDK();
        (usdk, engine, config) = deployer.deploy();
        weth = ERC20Mock(config.weth);
        wbtc = ERC20Mock(config.wbtc);
        wethUsdPriceFeed = MockV3Aggregator(config.wethUsdPriceFeed);
        wbtcUsdPriceFeed = MockV3Aggregator(config.wbtcUsdPriceFeed);

        weth.mint(alice, STARTING_USER_BALANCE);
        weth.mint(bob, STARTING_USER_BALANCE);
        wbtc.mint(alice, STARTING_USER_BALANCE);
        wbtc.mint(bob, STARTING_USER_BALANCE);
    }

    /* ------------------------- helpers ------------------------- */

    function _deposit(address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(token).approve(address(engine), amount);
        engine.deposit(token, amount);
        vm.stopPrank();
    }

    function _mintUSDK(address user, uint256 amount) internal {
        vm.prank(user);
        engine.mint(amount);
    }

    function _openPosition(address user, address token, uint256 collateral, uint256 debt) internal {
        _deposit(user, token, collateral);
        _mintUSDK(user, debt);
    }

    function _openPositionAtRatio(address user, address token, uint256 collateral, uint256 ratioBps)
        internal
        returns (uint256 debt)
    {
        _deposit(user, token, collateral);
        debt = _getMaxSafeMint(user) * ratioBps / 10_000;
        _mintUSDK(user, debt);
    }

    function _fundLiquidator(address liquidator, uint256 usdkAmount) internal {
        _deposit(liquidator, address(weth), 100 ether);
        _mintUSDK(liquidator, usdkAmount);
        _approveUSDK(liquidator, usdkAmount);
    }

    function _getMaxSafeMint(address user) internal view returns (uint256) {
        return engine.getUserTotalCollateralUsd(user);
    }

    function _approveUSDK(address user, uint256 amount) internal {
        vm.prank(user);
        usdk.approve(address(engine), amount);
    }

    /* ------------------------- initialization ------------------------- */

    function testInitializationCorrectly() public view {
        assertEq(engine.getUsdkAddr(), address(usdk));
        assertEq(usdk.owner(), address(engine));

        (address wethPriceFeed, uint256 wethThreshold) = engine.getCollateralConfig(address(weth));
        (address wbtcPriceFeed, uint256 wbtcThreshold) = engine.getCollateralConfig(address(wbtc));
        assertEq(wethPriceFeed, config.wethUsdPriceFeed);
        assertEq(wbtcPriceFeed, config.wbtcUsdPriceFeed);
        assertEq(wethThreshold, WETH_THRESHOLD);
        assertEq(wbtcThreshold, WBTC_THRESHOLD);

        assertEq(engine.getCollateralTokens().length, 2);
        assertTrue(engine.isAllowedCollateral(address(weth)));
        assertTrue(engine.isAllowedCollateral(address(wbtc)));
        assertFalse(engine.isAllowedCollateral(randomToken));

        assertEq(engine.getTokenUsdPrice(address(weth)), ETH_PRICE);
        assertEq(engine.getTokenUsdPrice(address(wbtc)), BTC_PRICE);
    }

    /* ------------------------- constructor reverts ------------------------- */

    function test_RevertConstructorTokenParamsLengthMismatch() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](2);
        uint256[] memory thresholds = new uint256[](1);
        tokens[0] = address(weth);
        feeds[0] = address(wethUsdPriceFeed);
        feeds[1] = address(wbtcUsdPriceFeed);
        thresholds[0] = WETH_THRESHOLD;

        vm.expectRevert(USDKEngine.USDKEngine_TokenParamsLengthMustBeSame.selector);
        new USDKEngine(address(usdk), tokens, feeds, thresholds);
    }

    function test_RevertConstructorZeroUsdk() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        uint256[] memory thresholds = new uint256[](1);
        tokens[0] = address(weth);
        feeds[0] = address(wethUsdPriceFeed);
        thresholds[0] = WETH_THRESHOLD;

        vm.expectRevert(USDKEngine.USDKEngine_ZeroAddress.selector);
        new USDKEngine(address(0), tokens, feeds, thresholds);
    }

    function test_RevertConstructorInvalidLiquidationThreshold() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        uint256[] memory thresholds = new uint256[](1);
        tokens[0] = address(weth);
        feeds[0] = address(wethUsdPriceFeed);
        thresholds[0] = 0;

        vm.expectRevert(USDKEngine.USDKEngine_InvalidLiquidationThresholds.selector);
        new USDKEngine(address(usdk), tokens, feeds, thresholds);

        thresholds[0] = 10001;
        vm.expectRevert(USDKEngine.USDKEngine_InvalidLiquidationThresholds.selector);
        new USDKEngine(address(usdk), tokens, feeds, thresholds);
    }

    function test_RevertConstructorZeroTokenOrFeed() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        uint256[] memory thresholds = new uint256[](1);
        thresholds[0] = WETH_THRESHOLD;

        tokens[0] = address(0);
        feeds[0] = address(wethUsdPriceFeed);
        vm.expectRevert(USDKEngine.USDKEngine_ZeroAddress.selector);
        new USDKEngine(address(usdk), tokens, feeds, thresholds);

        tokens[0] = address(weth);
        feeds[0] = address(0);
        vm.expectRevert(USDKEngine.USDKEngine_ZeroAddress.selector);
        new USDKEngine(address(usdk), tokens, feeds, thresholds);
    }

    /* ------------------------- deposit / redeem ------------------------- */

    function testDeposit() public {
        uint256 engineBalanceBefore = weth.balanceOf(address(engine));

        vm.startPrank(alice);
        weth.approve(address(engine), AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(weth), AMOUNT_TO_DEPOSIT);
        engine.deposit(address(weth), AMOUNT_TO_DEPOSIT);
        vm.stopPrank();

        assertEq(engine.getUserCollateral(alice, address(weth)), AMOUNT_TO_DEPOSIT);
        assertEq(weth.balanceOf(address(engine)), engineBalanceBefore + AMOUNT_TO_DEPOSIT);
    }

    function test_RevertDepositZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_NumberMustBeMoreThanZero.selector);
        engine.deposit(address(weth), 0);
    }

    function test_RevertDepositUnsupportedToken() public {
        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_UnsupportedToken.selector);
        engine.deposit(randomToken, 1 ether);
    }

    function test_RevertDepositWithoutApproval() public {
        vm.prank(alice);
        vm.expectRevert();
        engine.deposit(address(weth), 1 ether);
    }

    function testRedeem() public depositCollateral {
        uint256 redeemAmount = AMOUNT_TO_DEPOSIT / 2;
        uint256 aliceBalanceBefore = weth.balanceOf(alice);

        vm.prank(alice);
        engine.redeem(address(weth), redeemAmount);

        assertEq(engine.getUserCollateral(alice, address(weth)), AMOUNT_TO_DEPOSIT - redeemAmount);
        assertEq(weth.balanceOf(alice), aliceBalanceBefore + redeemAmount);
        assertEq(engine.getHealthFactor(alice), type(uint256).max);
    }

    function test_RevertRedeemMoreThanCollateral() public depositCollateral {
        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_InsufficientCollateralToRedeem.selector);
        engine.redeem(address(weth), AMOUNT_TO_DEPOSIT + 1);
    }

    function test_RevertRedeemBreaksHealthFactor() public {
        uint256 collateral = 10 ether;
        _deposit(alice, address(weth), collateral);
        _mintUSDK(alice, _getMaxSafeMint(alice));

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_BreakHealthFactor.selector);
        engine.redeem(address(weth), collateral);
    }

    /* ------------------------- mint / burn ------------------------- */

    function testMint() public depositCollateral {
        uint256 mintAmount = 10_000e18;
        uint256 maxMint = _getMaxSafeMint(alice);
        assertTrue(mintAmount <= maxMint);

        vm.expectEmit(true, true, true, true);
        emit Mint(alice, mintAmount);
        _mintUSDK(alice, mintAmount);

        assertEq(engine.getUserDebt(alice), mintAmount);
        assertEq(usdk.balanceOf(alice), mintAmount);
        assertGe(engine.getHealthFactor(alice), MIN_HEALTH_FACTOR);
    }

    function testDepositAndMint() public {
        uint256 depositAmount = 10 ether;
        uint256 mintAmount = 5_000e18;

        weth.mint(alice, depositAmount);
        vm.startPrank(alice);
        weth.approve(address(engine), depositAmount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, address(weth), depositAmount);
        vm.expectEmit(true, true, true, true);
        emit Mint(alice, mintAmount);
        engine.depositAndMint(address(weth), depositAmount, mintAmount);
        vm.stopPrank();

        assertEq(engine.getUserCollateral(alice, address(weth)), depositAmount);
        assertEq(engine.getUserDebt(alice), mintAmount);
        assertGe(engine.getHealthFactor(alice), MIN_HEALTH_FACTOR);
    }

    function testBurn() public depositCollateral {
        uint256 mintAmount = 10_000e18;
        _mintUSDK(alice, mintAmount);

        uint256 supplyBefore = usdk.totalSupply();
        _approveUSDK(alice, mintAmount);

        vm.expectEmit(true, true, true, true);
        emit Burn(alice, mintAmount);
        vm.prank(alice);
        engine.burn(mintAmount);

        assertEq(engine.getUserDebt(alice), 0);
        assertEq(usdk.balanceOf(alice), 0);
        assertEq(usdk.totalSupply(), supplyBefore - mintAmount);
    }

    function testRedeemAndBurn() public depositCollateral {
        uint256 mintAmount = 10_000e18;
        _mintUSDK(alice, mintAmount);

        uint256 redeemAmount = 5 ether;
        uint256 burnAmount = 5_000e18;
        _approveUSDK(alice, burnAmount);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Redeem(alice, address(weth), redeemAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(alice, burnAmount);
        engine.redeemAndBurn(address(weth), redeemAmount, burnAmount);
        vm.stopPrank();

        assertEq(engine.getUserCollateral(alice, address(weth)), AMOUNT_TO_DEPOSIT - redeemAmount);
        assertEq(engine.getUserDebt(alice), mintAmount - burnAmount);
        assertGe(engine.getHealthFactor(alice), MIN_HEALTH_FACTOR);
    }

    function test_RevertMintBreaksHealthFactor() public {
        _deposit(alice, address(weth), 1 ether);
        uint256 maxMint = _getMaxSafeMint(alice);

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_BreakHealthFactor.selector);
        engine.mint(maxMint + 1);
    }

    function test_RevertBurnMoreThanDebt() public depositCollateral {
        _mintUSDK(alice, 1_000e18);
        _approveUSDK(alice, 2_000e18);

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_DebtNotEnough.selector);
        engine.burn(2_000e18);
    }

    function test_RevertMintZeroAmount() public depositCollateral {
        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_NumberMustBeMoreThanZero.selector);
        engine.mint(0);
    }

    function test_RevertBurnZeroAmount() public depositCollateral {
        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_NumberMustBeMoreThanZero.selector);
        engine.burn(0);
    }

    /* ------------------------- health factor / pure ------------------------- */

    function testHealthFactorNoDebt() public depositCollateral {
        assertEq(engine.getHealthFactor(alice), type(uint256).max);
    }

    function testHealthFactorAfterMint() public depositCollateral {
        uint256 mintAmount = 50_000e18;
        _mintUSDK(alice, mintAmount);

        uint256 collateralUsd = engine.getUserTotalCollateralUsd(alice);
        uint256 expected = engine.calculateHealthFactor(collateralUsd, mintAmount);
        assertEq(engine.getHealthFactor(alice), expected);
        assertGe(expected, MIN_HEALTH_FACTOR);
    }

    function testCalculateBonus() public view {
        uint256 amount = 100e18;
        assertEq(engine.calculateBonus(amount), amount * LIQUIDATION_BONUS / LIQUIDATION_PRECISION);
    }

    /* ------------------------- oracle ------------------------- */

    function test_RevertStalePrice() public depositCollateral {
        vm.warp(block.timestamp + 2 hours + 1 seconds);

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_FrozenPrice.selector);
        engine.mint(1);
    }

    function test_RevertZeroPrice() public depositCollateral {
        wethUsdPriceFeed.updateAnswer(0);

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_PriceMustBeMoreThanZero.selector);
        engine.mint(1);
    }

    /* ------------------------- liquidate ------------------------- */

    function testLiquidate() public {
        uint256 collateral = 100 ether;
        _openPositionAtRatio(alice, address(weth), collateral, 9000);

        wethUsdPriceFeed.updateAnswer(1700e8);
        uint256 hfBefore = engine.getHealthFactor(alice);
        assertLt(hfBefore, MIN_HEALTH_FACTOR);

        uint256 debtToCover = engine.getMaxDeptToCover(alice);
        _fundLiquidator(bob, debtToCover);

        uint256 bobWethBefore = weth.balanceOf(bob);
        uint256 aliceDebtBefore = engine.getUserDebt(alice);

        vm.prank(bob);
        engine.liquidate(alice, address(weth), debtToCover);

        assertGt(engine.getHealthFactor(alice), hfBefore);
        assertLt(engine.getUserDebt(alice), aliceDebtBefore);
        assertGt(weth.balanceOf(bob), bobWethBefore);
        assertEq(engine.getTotalDebt(), usdk.totalSupply());
    }

    function testLiquidationAmountsMatchExecution() public {
        uint256 collateral = 100 ether;
        _openPositionAtRatio(alice, address(weth), collateral, 9000);
        wethUsdPriceFeed.updateAnswer(1700e8);

        uint256 debtToCover = engine.getMaxDeptToCover(alice);
        (uint256 expectedDebt, uint256 expectedCollateral,) =
            engine.getLiquidationAmounts(alice, address(weth), debtToCover);

        _fundLiquidator(bob, debtToCover);

        uint256 aliceCollateralBefore = engine.getUserCollateral(alice, address(weth));
        uint256 aliceDebtBefore = engine.getUserDebt(alice);
        vm.prank(bob);
        engine.liquidate(alice, address(weth), debtToCover);

        assertEq(aliceCollateralBefore - engine.getUserCollateral(alice, address(weth)), expectedCollateral);
        assertEq(aliceDebtBefore - engine.getUserDebt(alice), expectedDebt);
    }

    function test_RevertLiquidateHealthyAccount() public depositCollateral {
        vm.prank(bob);
        vm.expectRevert(USDKEngine.USDKEngine_AccountIsHealthy.selector);
        engine.liquidate(alice, address(weth), 1);
    }

    function test_RevertLiquidateExceedMaxDebtToCover() public {
        _openPositionAtRatio(alice, address(weth), 100 ether, 9000);
        wethUsdPriceFeed.updateAnswer(1700e8);

        uint256 maxCover = engine.getMaxDeptToCover(alice);
        _fundLiquidator(bob, maxCover + 1);

        vm.prank(bob);
        vm.expectRevert(USDKEngine.USDKEngine_ExceedMaximumValue.selector);
        engine.liquidate(alice, address(weth), maxCover + 1);
    }

    function test_RevertLiquidateZeroAccount() public {
        vm.prank(bob);
        vm.expectRevert(USDKEngine.USDKEngine_ZeroAddress.selector);
        engine.liquidate(address(0), address(weth), 1);
    }

    function test_RevertLiquidateNoCollateralOnToken() public {
        _openPositionAtRatio(alice, address(weth), 100 ether, 9000);
        wethUsdPriceFeed.updateAnswer(1700e8);

        uint256 debtToCover = engine.getMaxDeptToCover(alice);
        _fundLiquidator(bob, debtToCover);

        vm.prank(bob);
        vm.expectRevert(USDKEngine.USDKEngine_InsufficientCollateralToRedeem.selector);
        engine.liquidate(alice, address(wbtc), debtToCover);
    }

    /* ------------------------- accounting ------------------------- */

    function testTotalDebtEqualsSupply() public {
        _openPosition(alice, address(weth), 10 ether, 10_000e18);
        _openPosition(bob, address(wbtc), 1 ether, 1_000e18);
        assertEq(engine.getTotalDebt(), usdk.totalSupply());

        _approveUSDK(alice, 5_000e18);
        vm.prank(alice);
        engine.burn(5_000e18);
        assertEq(engine.getTotalDebt(), usdk.totalSupply());
    }

    /* ------------------------- fuzz ------------------------- */

    function testFuzzCalculateHealthFactor(uint256 collateralUsd, uint256 debt) public view {
        vm.assume(debt > 0);
        vm.assume(debt < type(uint128).max);
        vm.assume(collateralUsd < type(uint256).max / 1e18);

        uint256 expected = collateralUsd * 1e18 / debt;
        assertEq(engine.calculateHealthFactor(collateralUsd, debt), expected);
    }

    function testFuzzCalculateBonus(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);
        assertEq(engine.calculateBonus(amount), amount * LIQUIDATION_BONUS / LIQUIDATION_PRECISION);
    }

    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 1, AMOUNT_TO_DEPOSIT);
        weth.mint(alice, amount);

        uint256 engineBalanceBefore = weth.balanceOf(address(engine));
        _deposit(alice, address(weth), amount);

        assertEq(engine.getUserCollateral(alice, address(weth)), amount);
        assertEq(weth.balanceOf(address(engine)), engineBalanceBefore + amount);
    }

    function testFuzzMintWithinHealthFactor(uint256 collateral, uint256 mintAmount) public {
        collateral = bound(collateral, 1 ether, 100 ether);
        weth.mint(alice, collateral);
        _deposit(alice, address(weth), collateral);

        uint256 maxMint = _getMaxSafeMint(alice);
        vm.assume(maxMint > 0);
        mintAmount = bound(mintAmount, 1, maxMint);

        _mintUSDK(alice, mintAmount);
        assertGe(engine.getHealthFactor(alice), MIN_HEALTH_FACTOR);
    }

    function testFuzzCantMintAboveHealthFactor(uint256 mintAmount) public {
        uint256 collateral = 1 ether;
        weth.mint(alice, collateral);
        _deposit(alice, address(weth), collateral);

        uint256 maxMint = _getMaxSafeMint(alice);
        vm.assume(maxMint < type(uint256).max - 1);
        mintAmount = bound(mintAmount, maxMint + 1, type(uint128).max);

        vm.prank(alice);
        vm.expectRevert(USDKEngine.USDKEngine_BreakHealthFactor.selector);
        engine.mint(mintAmount);
    }

    function testFuzzBurnReducesDebt(uint256 mintAmount, uint256 burnAmount) public depositCollateral {
        uint256 maxMint = _getMaxSafeMint(alice);
        vm.assume(maxMint > 0);
        mintAmount = bound(mintAmount, 1, maxMint);
        burnAmount = bound(burnAmount, 1, mintAmount);

        _mintUSDK(alice, mintAmount);
        _approveUSDK(alice, burnAmount);

        uint256 debtBefore = engine.getUserDebt(alice);
        uint256 balanceBefore = usdk.balanceOf(alice);

        vm.prank(alice);
        engine.burn(burnAmount);

        assertEq(engine.getUserDebt(alice), debtBefore - burnAmount);
        assertEq(usdk.balanceOf(alice), balanceBefore - burnAmount);
    }
}
