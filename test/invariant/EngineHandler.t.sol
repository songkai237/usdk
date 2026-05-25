// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDKEngine} from "../../src/USDKEngine.sol";
import {USDK} from "../../src/USDK.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";
import {MockAddress} from "../mock/MockAddress.t.sol";

contract EngineHandler is Test, MockAddress {
    USDKEngine public engine;
    USDK public usdk;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant USER_COUNT = 7;

    uint256 public ghostMinted;
    uint256 public ghostBurned;
    uint256 public ghostLiquidatedDebt;
    uint256 public ghostDepositedWeth;
    uint256 public ghostDepositedWbtc;
    uint256 public ghostRedeemedWeth;
    uint256 public ghostRedeemedWbtc;
    uint256 public ghostLiquidatedWeth;
    uint256 public ghostLiquidatedWbtc;

    constructor(USDKEngine _engine, USDK _usdk, ERC20Mock _weth, ERC20Mock _wbtc) {
        engine = _engine;
        usdk = _usdk;
        weth = _weth;
        wbtc = _wbtc;
    }

    function deposit(uint256 userIdx, uint256 tokenIdx, uint256 amount) public {
        address user = _getUser(userIdx);
        ERC20Mock token = _getToken(tokenIdx);
        amount = bound(amount, 1, 100 ether);

        vm.startPrank(user);
        token.approve(address(engine), amount);
        try engine.deposit(address(token), amount) {
            if (address(token) == address(weth)) {
                ghostDepositedWeth += amount;
            } else {
                ghostDepositedWbtc += amount;
            }
        } catch {}
        vm.stopPrank();
    }

    function redeem(uint256 userIdx, uint256 tokenIdx, uint256 amount) public {
        address user = _getUser(userIdx);
        ERC20Mock token = _getToken(tokenIdx);
        amount = bound(amount, 1, type(uint128).max);

        vm.prank(user);
        try engine.redeem(address(token), amount) {
            if (address(token) == address(weth)) {
                ghostRedeemedWeth += amount;
            } else {
                ghostRedeemedWbtc += amount;
            }
        } catch {}
    }

    function mint(uint256 userIdx, uint256 amount) public {
        address user = _getUser(userIdx);
        amount = bound(amount, 1, 100_000e18);

        uint256 debtBefore = engine.getUserDebt(user);
        vm.prank(user);
        try engine.mint(amount) {
            ghostMinted += engine.getUserDebt(user) - debtBefore;
        } catch {}
    }

    function burn(uint256 userIdx, uint256 amount) public {
        address user = _getUser(userIdx);
        amount = bound(amount, 1, type(uint128).max);

        uint256 debtBefore = engine.getUserDebt(user);
        vm.startPrank(user);
        usdk.approve(address(engine), amount);
        try engine.burn(amount) {
            ghostBurned += debtBefore - engine.getUserDebt(user);
        } catch {}
        vm.stopPrank();
    }

    function depositAndMint(uint256 userIdx, uint256 tokenIdx, uint256 depositAmount, uint256 mintAmount) public {
        address user = _getUser(userIdx);
        ERC20Mock token = _getToken(tokenIdx);
        depositAmount = bound(depositAmount, 1, 50 ether);
        mintAmount = bound(mintAmount, 1, 50_000e18);

        uint256 debtBefore = engine.getUserDebt(user);
        vm.startPrank(user);
        token.approve(address(engine), depositAmount);
        try engine.depositAndMint(address(token), depositAmount, mintAmount) {
            if (address(token) == address(weth)) {
                ghostDepositedWeth += depositAmount;
            } else {
                ghostDepositedWbtc += depositAmount;
            }
            ghostMinted += engine.getUserDebt(user) - debtBefore;
        } catch {}
        vm.stopPrank();
    }

    function redeemAndBurn(uint256 userIdx, uint256 tokenIdx, uint256 redeemAmount, uint256 burnAmount) public {
        address user = _getUser(userIdx);
        ERC20Mock token = _getToken(tokenIdx);
        redeemAmount = bound(redeemAmount, 1, type(uint128).max);
        burnAmount = bound(burnAmount, 1, type(uint128).max);

        uint256 debtBefore = engine.getUserDebt(user);
        vm.startPrank(user);
        usdk.approve(address(engine), burnAmount);
        try engine.redeemAndBurn(address(token), redeemAmount, burnAmount) {
            if (address(token) == address(weth)) {
                ghostRedeemedWeth += redeemAmount;
            } else {
                ghostRedeemedWbtc += redeemAmount;
            }
            ghostBurned += debtBefore - engine.getUserDebt(user);
        } catch {}
        vm.stopPrank();
    }

    function transferUsdk(uint256 fromIdx, uint256 toIdx, uint256 amount) public {
        address from = _getUser(fromIdx);
        address to = _getUser(toIdx);
        amount = bound(amount, 0, type(uint128).max);

        vm.prank(from);
        try usdk.transfer(to, amount) {} catch {}
    }

    function liquidate(uint256 liquidatorIdx, uint256 victimIdx, uint256 tokenIdx, uint256 debtToCover) public {
        address liquidator = _getUser(liquidatorIdx);
        address victim = _getUser(victimIdx);
        ERC20Mock token = _getToken(tokenIdx);
        debtToCover = bound(debtToCover, 1, type(uint128).max);

        uint256 victimDebtBefore = engine.getUserDebt(victim);
        uint256 victimColBefore = engine.getUserCollateral(victim, address(token));

        vm.startPrank(liquidator);
        usdk.approve(address(engine), debtToCover);
        try engine.liquidate(victim, address(token), debtToCover) {
            uint256 debtCovered = victimDebtBefore - engine.getUserDebt(victim);
            uint256 colTaken = victimColBefore - engine.getUserCollateral(victim, address(token));
            ghostLiquidatedDebt += debtCovered;
            if (address(token) == address(weth)) {
                ghostLiquidatedWeth += colTaken;
            } else {
                ghostLiquidatedWbtc += colTaken;
            }
        } catch {}
        vm.stopPrank();
    }

    function sumUserDebts() public view returns (uint256 total) {
        for (uint256 i; i < USER_COUNT; ++i) {
            total += engine.getUserDebt(addresses[i]);
        }
    }

    function sumUserCollateral(address token) public view returns (uint256 total) {
        for (uint256 i; i < USER_COUNT; ++i) {
            total += engine.getUserCollateral(addresses[i], token);
        }
    }

    function sumUsdkBalances() public view returns (uint256 total) {
        for (uint256 i; i < USER_COUNT; ++i) {
            total += usdk.balanceOf(addresses[i]);
        }
        total += usdk.balanceOf(address(engine));
    }

    function _getUser(uint256 userIdx) internal view returns (address) {
        return addresses[bound(userIdx, 0, USER_COUNT - 1)];
    }

    function _getToken(uint256 tokenIdx) internal view returns (ERC20Mock) {
        tokenIdx = bound(tokenIdx, 0, 1);
        if (tokenIdx == 0) {
            return weth;
        }
        return wbtc;
    }
}
