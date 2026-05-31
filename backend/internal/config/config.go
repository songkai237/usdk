package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Deployment struct {
	ChainID           int    `json:"chainId"`
	RPCURL            string `json:"rpcUrl"`
	USDK              string `json:"usdk"`
	Engine            string `json:"engine"`
	WETH              string `json:"weth"`
	WBTC              string `json:"wbtc"`
	WETHUsdPriceFeed  string `json:"wethUsdPriceFeed"`
	WBTCUsdPriceFeed  string `json:"wbtcUsdPriceFeed"`
}

type Config struct {
	Deployment Deployment
	Port       string
	ABIDir     string
}

func Load() (*Config, error) {
	deployPath := os.Getenv("DEPLOYMENTS_PATH")
	if deployPath == "" {
		deployPath = filepath.Join("..", "deployments", "31337.json")
	}

	data, err := os.ReadFile(deployPath)
	if err != nil {
		return nil, fmt.Errorf("read deployment: %w", err)
	}

	var dep Deployment
	if err := json.Unmarshal(data, &dep); err != nil {
		return nil, fmt.Errorf("parse deployment: %w", err)
	}

	if rpc := os.Getenv("RPC_URL"); rpc != "" {
		dep.RPCURL = rpc
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	abiDir := os.Getenv("ABI_DIR")
	if abiDir == "" {
		abiDir = filepath.Join("..", "frontend", "src", "abi")
	}

	return &Config{
		Deployment: dep,
		Port:       port,
		ABIDir:     abiDir,
	}, nil
}
