// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {USDKEngine} from "../../src/USDKEngine.sol";
import {USDK} from "../../src/USDK.sol";
import {DeployUSDK} from "../../script/DeployUSDK.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {EngineHandler} from "./EngineHandler.t.sol";

contract EngineInvariantTest is StdInvariant, Test {
    EngineHandler public handler;

    USDKEngine public engine;
    USDK public usdk;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant USER_COUNT = 7;

    function setUp() public {
        DeployUSDK deployer = new DeployUSDK();
        HelperConfig.NetworkConfig memory config;
        (usdk, engine, config) = deployer.deploy();

        weth = ERC20Mock(config.weth);
        wbtc = ERC20Mock(config.wbtc);

        handler = new EngineHandler(engine, usdk, weth, wbtc);

        for (uint256 i; i < USER_COUNT; ++i) {
            weth.mint(handler.addresses(i), STARTING_USER_BALANCE);
            wbtc.mint(handler.addresses(i), STARTING_USER_BALANCE);
        }

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.redeem.selector;
        selectors[2] = handler.mint.selector;
        selectors[3] = handler.burn.selector;
        selectors[4] = handler.depositAndMint.selector;
        selectors[5] = handler.redeemAndBurn.selector;
        selectors[6] = handler.transferUsdk.selector;
        selectors[7] = handler.liquidate.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_sumOfUserDebtsEqualsSupply() public view {
        assertEq(handler.sumUserDebts(), usdk.totalSupply());
        assertEq(handler.sumUserDebts(), engine.getTotalDebt());
    }

    function statefulFuzz_usdkBalancesEqualSupply() public view {
        assertEq(handler.sumUsdkBalances(), usdk.totalSupply());
    }

    function statefulFuzz_wethCollateralBalance() public view {
        uint256 inEngine = weth.balanceOf(address(engine));
        uint256 accounted = handler.sumUserCollateral(address(weth));
        assertEq(inEngine, accounted);
        assertEq(
            inEngine,
            handler.ghostDepositedWeth() - handler.ghostRedeemedWeth() - handler.ghostLiquidatedWeth()
        );
    }

    function statefulFuzz_wbtcCollateralBalance() public view {
        uint256 inEngine = wbtc.balanceOf(address(engine));
        uint256 accounted = handler.sumUserCollateral(address(wbtc));
        assertEq(inEngine, accounted);
        assertEq(
            inEngine,
            handler.ghostDepositedWbtc() - handler.ghostRedeemedWbtc() - handler.ghostLiquidatedWbtc()
        );
    }

    function statefulFuzz_ghostAccountingMatchesSupply() public view {
        uint256 netMinted = handler.ghostMinted() - handler.ghostBurned() - handler.ghostLiquidatedDebt();
        assertEq(netMinted, usdk.totalSupply());
        assertEq(netMinted, handler.sumUserDebts());
    }

    function statefulFuzz_healthFactorOfBorrowers() public view {
        for (uint256 i; i < USER_COUNT; ++i) {
            address user = handler.addresses(i);
            uint256 debt = engine.getUserDebt(user);
            if (debt > 0) {
                assertGe(engine.getHealthFactor(user), MIN_HEALTH_FACTOR);
            }
        }
    }
}
