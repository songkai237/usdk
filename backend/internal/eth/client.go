package eth

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/songkai/usdk/backend/internal/config"
)

type Client struct {
	cfg    *config.Deployment
	client *ethclient.Client
	engine abi.ABI
	usdk   abi.ABI
	erc20  abi.ABI
}

func NewClient(cfg *config.Config) (*Client, error) {
	client, err := ethclient.Dial(cfg.Deployment.RPCURL)
	if err != nil {
		return nil, fmt.Errorf("dial rpc: %w", err)
	}

	engineABI, err := loadABI(cfg.ABIDir, "USDKEngine.json")
	if err != nil {
		return nil, err
	}
	usdkABI, err := loadABI(cfg.ABIDir, "USDK.json")
	if err != nil {
		return nil, err
	}
	erc20ABI, err := loadABI(cfg.ABIDir, "ERC20Mock.json")
	if err != nil {
		return nil, err
	}

	return &Client{
		cfg:    &cfg.Deployment,
		client: client,
		engine: engineABI,
		usdk:   usdkABI,
		erc20:  erc20ABI,
	}, nil
}

func loadABI(dir, name string) (abi.ABI, error) {
	data, err := os.ReadFile(filepath.Join(dir, name))
	if err != nil {
		return abi.ABI{}, fmt.Errorf("read abi %s: %w", name, err)
	}
	parsed, err := abi.JSON(strings.NewReader(string(data)))
	if err != nil {
		return abi.ABI{}, fmt.Errorf("parse abi %s: %w", name, err)
	}
	return parsed, nil
}

func (c *Client) EngineAddr() common.Address {
	return common.HexToAddress(c.cfg.Engine)
}

func (c *Client) USDKAddr() common.Address {
	return common.HexToAddress(c.cfg.USDK)
}

func (c *Client) callEngine(ctx context.Context, method string, args ...interface{}) ([]byte, error) {
	data, err := c.engine.Pack(method, args...)
	if err != nil {
		return nil, err
	}
	addr := c.EngineAddr()
	return c.client.CallContract(ctx, ethereum.CallMsg{To: &addr, Data: data}, nil)
}

func (c *Client) callUSDK(ctx context.Context, method string, args ...interface{}) ([]byte, error) {
	data, err := c.usdk.Pack(method, args...)
	if err != nil {
		return nil, err
	}
	addr := c.USDKAddr()
	return c.client.CallContract(ctx, ethereum.CallMsg{To: &addr, Data: data}, nil)
}

func (c *Client) callERC20(ctx context.Context, token common.Address, method string, args ...interface{}) ([]byte, error) {
	data, err := c.erc20.Pack(method, args...)
	if err != nil {
		return nil, err
	}
	return c.client.CallContract(ctx, ethereum.CallMsg{To: &token, Data: data}, nil)
}

func unpackUint256(out []byte, parsed abi.ABI, method string) (*big.Int, error) {
	vals, err := parsed.Unpack(method, out)
	if err != nil {
		return nil, err
	}
	if len(vals) == 0 {
		return big.NewInt(0), nil
	}
	switch v := vals[0].(type) {
	case *big.Int:
		return v, nil
	default:
		return nil, fmt.Errorf("unexpected type for %s", method)
	}
}

func (c *Client) GetUserDebt(ctx context.Context, account common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getUserDebt", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getUserDebt")
}

func (c *Client) GetHealthFactor(ctx context.Context, account common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getHealthFactor", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getHealthFactor")
}

func (c *Client) GetUserTotalCollateralUsd(ctx context.Context, account common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getUserTotalCollateralUsd", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getUserTotalCollateralUsd")
}

func (c *Client) GetUserCollateral(ctx context.Context, account, token common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getUserCollateral", account, token)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getUserCollateral")
}

func (c *Client) GetTokenUsdPrice(ctx context.Context, token common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getTokenUsdPrice", token)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getTokenUsdPrice")
}

func (c *Client) GetMaxDebtToCover(ctx context.Context, account common.Address) (*big.Int, error) {
	out, err := c.callEngine(ctx, "getMaxDeptToCover", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.engine, "getMaxDeptToCover")
}

type LiquidationPreview struct {
	FinalDebtToCover  *big.Int
	CollateralAmount  *big.Int
	TotalUsdWithBonus *big.Int
}

func (c *Client) GetLiquidationAmounts(ctx context.Context, account, token common.Address, debtToCover *big.Int) (*LiquidationPreview, error) {
	out, err := c.callEngine(ctx, "getLiquidationAmounts", account, token, debtToCover)
	if err != nil {
		return nil, err
	}
	vals, err := c.engine.Unpack("getLiquidationAmounts", out)
	if err != nil {
		return nil, err
	}
	return &LiquidationPreview{
		FinalDebtToCover:  vals[0].(*big.Int),
		CollateralAmount:  vals[1].(*big.Int),
		TotalUsdWithBonus: vals[2].(*big.Int),
	}, nil
}

func (c *Client) BalanceOf(ctx context.Context, token, account common.Address) (*big.Int, error) {
	out, err := c.callERC20(ctx, token, "balanceOf", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.erc20, "balanceOf")
}

func (c *Client) Symbol(ctx context.Context, token common.Address) (string, error) {
	out, err := c.callERC20(ctx, token, "symbol")
	if err != nil {
		return "", err
	}
	vals, err := c.erc20.Unpack("symbol", out)
	if err != nil {
		return "", err
	}
	return vals[0].(string), nil
}

func (c *Client) USDKBalanceOf(ctx context.Context, account common.Address) (*big.Int, error) {
	out, err := c.callUSDK(ctx, "balanceOf", account)
	if err != nil {
		return nil, err
	}
	return unpackUint256(out, c.usdk, "balanceOf")
}

type CollateralToken struct {
	Address   string `json:"address"`
	Symbol    string `json:"symbol"`
	PriceFeed string `json:"priceFeed"`
}

type Position struct {
	Address       string              `json:"address"`
	Debt          string              `json:"debt"`
	HealthFactor  string              `json:"healthFactor"`
	CollateralUsd string              `json:"collateralUsd"`
	MaxSafeMint   string              `json:"maxSafeMint"`
	UsdkBalance   string              `json:"usdkBalance"`
	Collateral    []CollateralDetail  `json:"collateral"`
}

type CollateralDetail struct {
	Token           string `json:"token"`
	Symbol          string `json:"symbol"`
	Deposited       string `json:"deposited"`
	WalletBalance   string `json:"walletBalance"`
	UsdPrice        string `json:"usdPrice"`
}

func (c *Client) GetPosition(ctx context.Context, account common.Address) (*Position, error) {
	debt, err := c.GetUserDebt(ctx, account)
	if err != nil {
		return nil, err
	}
	hf, err := c.GetHealthFactor(ctx, account)
	if err != nil {
		return nil, err
	}
	colUsd, err := c.GetUserTotalCollateralUsd(ctx, account)
	if err != nil {
		return nil, err
	}
	usdkBal, err := c.USDKBalanceOf(ctx, account)
	if err != nil {
		return nil, err
	}

	tokens := []struct {
		addr   common.Address
		symbol string
		feed   string
	}{
		{common.HexToAddress(c.cfg.WETH), "WETH", c.cfg.WETHUsdPriceFeed},
		{common.HexToAddress(c.cfg.WBTC), "WBTC", c.cfg.WBTCUsdPriceFeed},
	}

	collateral := make([]CollateralDetail, 0, len(tokens))
	for _, t := range tokens {
		dep, err := c.GetUserCollateral(ctx, account, t.addr)
		if err != nil {
			return nil, err
		}
		wallet, err := c.BalanceOf(ctx, t.addr, account)
		if err != nil {
			return nil, err
		}
		price, err := c.GetTokenUsdPrice(ctx, t.addr)
		if err != nil {
			return nil, err
		}
		collateral = append(collateral, CollateralDetail{
			Token:         t.addr.Hex(),
			Symbol:        t.symbol,
			Deposited:     dep.String(),
			WalletBalance: wallet.String(),
			UsdPrice:      price.String(),
		})
	}

	return &Position{
		Address:       account.Hex(),
		Debt:          debt.String(),
		HealthFactor:  hf.String(),
		CollateralUsd: colUsd.String(),
		MaxSafeMint:   colUsd.String(),
		UsdkBalance:   usdkBal.String(),
		Collateral:    collateral,
	}, nil
}

type HealthResponse struct {
	HealthFactor  string `json:"healthFactor"`
	HealthFactorF string `json:"healthFactorFormatted"`
	CanLiquidate  bool   `json:"canLiquidate"`
	MinHealth     string `json:"minHealthFactor"`
}

var minHealthFactor = new(big.Int).Exp(big.NewInt(10), big.NewInt(18), nil)

func (c *Client) GetHealth(ctx context.Context, account common.Address) (*HealthResponse, error) {
	hf, err := c.GetHealthFactor(ctx, account)
	if err != nil {
		return nil, err
	}
	hfFloat := new(big.Float).Quo(
		new(big.Float).SetInt(hf),
		new(big.Float).SetInt(minHealthFactor),
	)
	canLiq := hf.Cmp(minHealthFactor) < 0
	return &HealthResponse{
		HealthFactor:  hf.String(),
		HealthFactorF: hfFloat.Text('f', 4),
		CanLiquidate:  canLiq,
		MinHealth:     minHealthFactor.String(),
	}, nil
}

type PriceResponse struct {
	WETH string `json:"weth"`
	WBTC string `json:"wbtc"`
}

func (c *Client) GetPrices(ctx context.Context) (*PriceResponse, error) {
	wethPrice, err := c.GetTokenUsdPrice(ctx, common.HexToAddress(c.cfg.WETH))
	if err != nil {
		return nil, err
	}
	wbtcPrice, err := c.GetTokenUsdPrice(ctx, common.HexToAddress(c.cfg.WBTC))
	if err != nil {
		return nil, err
	}
	return &PriceResponse{
		WETH: wethPrice.String(),
		WBTC: wbtcPrice.String(),
	}, nil
}

type ConfigResponse struct {
	ChainID          int               `json:"chainId"`
	RPCURL           string            `json:"rpcUrl"`
	USDK             string            `json:"usdk"`
	Engine           string            `json:"engine"`
	CollateralTokens []CollateralToken `json:"collateralTokens"`
	PriceFeeds       map[string]string `json:"priceFeeds"`
}

func (c *Client) GetConfigResponse() *ConfigResponse {
	return &ConfigResponse{
		ChainID: c.cfg.ChainID,
		RPCURL:  c.cfg.RPCURL,
		USDK:    c.cfg.USDK,
		Engine:  c.cfg.Engine,
		CollateralTokens: []CollateralToken{
			{Address: c.cfg.WETH, Symbol: "WETH", PriceFeed: c.cfg.WETHUsdPriceFeed},
			{Address: c.cfg.WBTC, Symbol: "WBTC", PriceFeed: c.cfg.WBTCUsdPriceFeed},
		},
		PriceFeeds: map[string]string{
			"weth": c.cfg.WETHUsdPriceFeed,
			"wbtc": c.cfg.WBTCUsdPriceFeed,
		},
	}
}
