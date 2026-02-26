// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {USDK} from "./USDK.sol";
import {IERC20} from "./interface/IERC20.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
 * @title USDK engine
 * @author SongKai
 */
contract USDKEngine is ReentrancyGuard {
    /**
     *
     */
    /*                         Struct                         */
    /**
     *
     */
    struct CollateralConfig {
        address priceFeed;
        uint256 liquidationThreshold;
    }

    /**
     *
     */
    /*                    State variables                     */
    /**
     *
     */
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD_PRECISION = 1e4;
    uint256 private constant MAX_DELAY = 2 hours;
    uint256 private constant LIQUIDATION_BONUS = 1000;
    uint256 private constant LIQUIDATION_PRECISION = 1e4;
    uint256 private constant MAX_DEBT_TO_COVER = 5000;

    USDK private immutable i_usdk;

    address[] private s_tokenList;
    mapping(address tokenAddress => bool) private s_allowedToken;
    mapping(address tokenAddress => CollateralConfig) private s_collateralConfigs;
    mapping(address account => mapping(address tokenAddress => uint256 amount)) private s_userCollateral;
    mapping(address account => uint256 amount) private s_debt;

    /**
     *
     */
    /*                         Errors                         */
    /**
     *
     */
    error USDKEngine_TokenParamsLengthMustBeSame();
    error USDKEngine_InvalidLiquidationThresholds();
    error USDKEngine_ZeroAddress();
    error USDKEngine_BreakHealthFactor();
    error USDKEngine_UnsupportedToken();
    error USDKEngine_InsufficientCollateralToRedeem();
    error USDKEngine_NumberMustBeMoreThanZero();
    error USDKEngine_DebtNotEnough();
    error USDKEngine_TransferFailed();
    error USDKEngine_PriceMustBeMoreThanZero();
    error USDKEngine_FrozenPrice();
    error USDKEngine_ExceedMaximumValue();
    error USDKEngine_AccountIsHealthy();
    error USDKEngine_HealthFactorMustBeRaised();

    /**
     *
     */
    /*                         Events                         */
    /**
     *
     */
    event Deposit(address indexed _account, address indexed _token, uint256 amount);
    event Redeem(address indexed _account, address indexed _token, uint256 amount);
    event Mint(address indexed _account, uint256 amount);
    event Burn(address indexed _account, uint256 amount);
    event Liquidate(address indexed _account, address indexed _liquidator, uint256 debtToCover);

    /**
     *
     */
    /*                       Modifiers                        */
    /**
     *
     */
    modifier isAllowedToken(address token) {
        if (token == address(0)) {
            revert USDKEngine_ZeroAddress();
        }
        if (!s_allowedToken[token]) {
            revert USDKEngine_UnsupportedToken();
        }
        _;
    }

    modifier zeroCheck(uint256 amount) {
        if (amount == 0) {
            revert USDKEngine_NumberMustBeMoreThanZero();
        }
        _;
    }

    /**
     *
     */
    /*                      Constructor                       */
    /**
     *
     */
    constructor(
        address _usdk,
        address[] memory _addresses,
        address[] memory _priceFeeds,
        uint256[] memory _liquidationThresholds
    ) {
        if (_addresses.length != _priceFeeds.length || _addresses.length != _liquidationThresholds.length) {
            revert USDKEngine_TokenParamsLengthMustBeSame();
        }
        if (_usdk == address(0)) {
            revert USDKEngine_ZeroAddress();
        }
        i_usdk = USDK(_usdk);
        uint256 _length = _addresses.length;
        for (uint256 i; i < _length; i++) {
            if (_liquidationThresholds[i] > LIQUIDATION_THRESHOLD_PRECISION || _liquidationThresholds[i] == 0) {
                revert USDKEngine_InvalidLiquidationThresholds();
            }
            if (_addresses[i] == address(0)) {
                revert USDKEngine_ZeroAddress();
            }
            if (_priceFeeds[i] == address(0)) {
                revert USDKEngine_ZeroAddress();
            }
            s_tokenList.push(_addresses[i]);
            s_allowedToken[_addresses[i]] = true;
            s_collateralConfigs[_addresses[i]] =
                CollateralConfig({priceFeed: _priceFeeds[i], liquidationThreshold: _liquidationThresholds[i]});
        }
    }

    /**
     *
     */
    /*                        External                        */
    /**
     *
     */
    function deposit(address token, uint256 amount) external isAllowedToken(token) zeroCheck(amount) nonReentrant {
        _deposit(token, amount);
        emit Deposit(msg.sender, token, amount);
    }

    function redeem(address token, uint256 amount) external isAllowedToken(token) zeroCheck(amount) nonReentrant {
        _redeem(msg.sender, msg.sender, token, amount);
        _revertIfBreakHealthFactor(msg.sender);
        emit Redeem(msg.sender, token, amount);
    }

    function depositAndMint(address token, uint256 amountToDeposit, uint256 amountToMint)
        external
        isAllowedToken(token)
        zeroCheck(amountToDeposit)
        zeroCheck(amountToMint)
        nonReentrant
    {
        _deposit(token, amountToDeposit);
        _mint(msg.sender, amountToMint);
        _revertIfBreakHealthFactor(msg.sender);
        emit Deposit(msg.sender, token, amountToDeposit);
        emit Mint(msg.sender, amountToMint);
    }

    function redeemAndBurn(address token, uint256 amountToRedeem, uint256 amountToBurn)
        external
        isAllowedToken(token)
        zeroCheck(amountToRedeem)
        zeroCheck(amountToBurn)
        nonReentrant
    {
        _burn(msg.sender, amountToBurn);
        _redeem(msg.sender, msg.sender, token, amountToRedeem);
        _revertIfBreakHealthFactor(msg.sender);
        emit Redeem(msg.sender, token, amountToRedeem);
        emit Burn(msg.sender, amountToBurn);
    }

    function mint(uint256 amount) external zeroCheck(amount) nonReentrant {
        _mint(msg.sender, amount);
        _revertIfBreakHealthFactor(msg.sender);
        emit Mint(msg.sender, amount);
    }

    function burn(uint256 amount) external zeroCheck(amount) nonReentrant {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    /*
     * AmountToRedeem = debtToCover / tokenInUsd
     *             if AmountToRedeem <= totalCollateral
     *                              /     \
     *                            true   false
     *                            /        \
     *             get AmountToRedeem     get amount of totalCollateral
     */
    function liquidate(address account, address collateralToken, uint256 debtToCover)
        external
        zeroCheck(debtToCover)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        if (account == address(0)) {
            revert USDKEngine_ZeroAddress();
        }
        uint256 healthFactorBefore = _healthFactor(account);
        if (healthFactorBefore >= MIN_HEALTH_FACTOR) {
            revert USDKEngine_AccountIsHealthy();
        }
        if (s_userCollateral[account][collateralToken] == 0) {
            revert USDKEngine_InsufficientCollateralToRedeem();
        }
        uint256 maxDebtToCover = _getMaxDebtToCover(account);
        if (debtToCover > maxDebtToCover) {
            revert USDKEngine_ExceedMaximumValue();
        }

        (uint256 finalDebtToCover, uint256 amountToRedeem,) =
            _getLiquidationAmounts(account, collateralToken, debtToCover);

        bool success = i_usdk.transferFrom(msg.sender, address(this), finalDebtToCover);
        if (!success) {
            revert USDKEngine_TransferFailed();
        }
        i_usdk.burn(finalDebtToCover);
        s_debt[account] -= finalDebtToCover;
        _redeem(account, msg.sender, collateralToken, amountToRedeem);

        // HF must be raised
        uint256 healthFactorAfter = _healthFactor(account);
        if (healthFactorAfter <= healthFactorBefore) {
            revert USDKEngine_HealthFactorMustBeRaised();
        }

        emit Liquidate(account, msg.sender, finalDebtToCover);
    }

    /**
     *
     */
    /*                     External view                      */
    /**
     *
     */
    function getUserCollateral(address account, address token) external view returns (uint256) {
        return s_userCollateral[account][token];
    }

    function getUserDebt(address account) external view returns (uint256) {
        return s_debt[account];
    }

    function getHealthFactor(address account) external view returns (uint256) {
        return _healthFactor(account);
    }

    function getUserTotalCollateralUsd(address account) external view returns (uint256) {
        return _getUserTotalCollateralUsd(account);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_tokenList;
    }

    function isAllowedCollateral(address token) external view returns (bool) {
        return s_allowedToken[token];
    }

    function getCollateralConfig(address token)
        external
        view
        returns (address priceFeed, uint256 liquidationThreshold)
    {
        CollateralConfig memory config = s_collateralConfigs[token];
        return (config.priceFeed, config.liquidationThreshold);
    }

    function getTokenUsdPrice(address token) external view returns (uint256) {
        return _getTokenUsdPrice(token);
    }

    function getMaxDeptToCover(address account) external view returns (uint256) {
        return _getMaxDebtToCover(account);
    }

    function getLiquidationAmounts(address account, address collateralToken, uint256 debtToCover)
        external
        view
        returns (uint256 finalDebtToCover, uint256 collateralAmount, uint256 totalUsdWithBonus)
    {
        return _getLiquidationAmounts(account, collateralToken, debtToCover);
    }

    function getTotalDebt() external view returns (uint256) {
        return i_usdk.totalSupply();
    }

    /**
     *
     */
    /*                         Public                         */
    /**
     *
     */
    function calculateHealthFactor(uint256 collateralUsd, uint256 debt) public pure returns (uint256) {
        if(debt == 0) {
            return type(uint256).max;
        }
        return collateralUsd * PRECISION / debt;
    }

    function calculateBonus(uint256 amount) public pure returns (uint256) {
        return amount * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;
    }

    /**
     *
     */
    /*                        Internal                        */
    /**
     *
     */

    /*
     * healthFactor = ∑(tokenValue * amount * liquidationThreshold) / USDK value
     */
    function _healthFactor(address _account) internal view returns (uint256) {
        uint256 debt = s_debt[_account];
        if (debt == 0) {
            return type(uint256).max;
        }

        uint256 sum = _getUserTotalCollateralUsd(_account);

        return calculateHealthFactor(sum, debt);
    }

    function _getUserTotalCollateralUsd(address _account) internal view returns (uint256) {
        uint256 sum;
        uint256 allowedTokenAmount = s_tokenList.length;

        for (uint256 i; i < allowedTokenAmount; ++i) {
            address _token = s_tokenList[i];
            uint256 userCollateralAmount = s_userCollateral[_account][_token];
            if (userCollateralAmount > 0) {
                uint256 threshold = s_collateralConfigs[_token].liquidationThreshold;
                sum += _getUsdValue(_token, userCollateralAmount) * threshold / LIQUIDATION_THRESHOLD_PRECISION;
            }
        }
        return sum;
    }

    function _getUsdValue(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20(_token).decimals();
        uint256 adjustedPrice = _getTokenUsdPrice(_token);
        uint256 adjustAmount = (_amount * PRECISION) / (10 ** uint256(tokenDecimals));

        return (adjustedPrice * adjustAmount) / PRECISION;
    }

    function _getTokenAmountByUsd(address _token, uint256 _usd) internal view returns (uint256) {
        uint256 price = _getTokenUsdPrice(_token);
        uint8 tokenDecimals = IERC20(_token).decimals();

        uint256 amountIn18 = _usd * PRECISION / price;

        return amountIn18 * (10 ** uint256(tokenDecimals)) / PRECISION;
    }

    function _getTokenUsdPrice(address _token) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralConfigs[_token].priceFeed);
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (answer <= 0) {
            revert USDKEngine_PriceMustBeMoreThanZero();
        }
        if (block.timestamp - updatedAt > MAX_DELAY) {
            revert USDKEngine_FrozenPrice();
        }

        // normalize to 1e18
        uint256 price = uint256(answer);
        uint8 priceDecimals = priceFeed.decimals();
        return (price * PRECISION) / (10 ** uint256(priceDecimals));
    }

    function _getMaxDebtToCover(address _account) internal view returns (uint256) {
        uint256 debt = s_debt[_account];
        return debt * MAX_DEBT_TO_COVER / LIQUIDATION_PRECISION;
    }

    function _revertIfBreakHealthFactor(address _account) internal {
        if (_healthFactor(_account) < MIN_HEALTH_FACTOR) {
            revert USDKEngine_BreakHealthFactor();
        }
    }

    function _deposit(address _token, uint256 amount) internal {
        IERC20 token = IERC20(_token);
        s_userCollateral[msg.sender][_token] += amount;
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert USDKEngine_TransferFailed();
        }
    }

    function _redeem(address _from, address _to, address _token, uint256 _amount) internal {
        if (_from == address(0) || _to == address(0)) {
            revert USDKEngine_ZeroAddress();
        }
        IERC20 token = IERC20(_token);
        if (s_userCollateral[_from][_token] < _amount) {
            revert USDKEngine_InsufficientCollateralToRedeem();
        }
        s_userCollateral[_from][_token] -= _amount;
        bool success = token.transfer(_to, _amount);
        if (!success) {
            revert USDKEngine_TransferFailed();
        }
    }

    function _mint(address _account, uint256 _amount) internal {
        s_debt[_account] += _amount;
        i_usdk.mint(_account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        if (s_debt[_account] < _amount) {
            revert USDKEngine_DebtNotEnough();
        }
        bool success = i_usdk.transferFrom(_account, address(this), _amount);
        if (!success) {
            revert USDKEngine_TransferFailed();
        }
        s_debt[_account] -= _amount;
        i_usdk.burn(_amount);
    }

    function _getLiquidationAmounts(address _account, address _collateralToken, uint256 _debtToCover)
        internal
        view
        returns (uint256 finalDebtToCover, uint256 collateralAmount, uint256 totalUsdWithBonus)
    {
        uint256 totalUsdWithBonus = _debtToCover + calculateBonus(_debtToCover);
        uint256 amountToRedeem = _getTokenAmountByUsd(_collateralToken, totalUsdWithBonus);
        uint256 userCollateralAmount = s_userCollateral[_account][_collateralToken];
        if (amountToRedeem > userCollateralAmount) {
            // (new debtToCover + bonus) / tokenValue = userCollateralAmount
            // new debtToCover = userCollateralAmount * tokenValue / (1 + LIQUIDATION_BONUS)
            _debtToCover = _getUsdValue(_collateralToken, userCollateralAmount) * LIQUIDATION_PRECISION
                / (LIQUIDATION_PRECISION + LIQUIDATION_BONUS);
            totalUsdWithBonus = _debtToCover + calculateBonus(_debtToCover);
            amountToRedeem = userCollateralAmount;
        }

        return (_debtToCover, amountToRedeem, totalUsdWithBonus);
    }
}
