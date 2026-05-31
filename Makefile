.PHONY: build test deploy-anvil export-abi backend frontend dev anvil

RPC_URL ?= http://127.0.0.1:8545
ANVIL_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEPLOYMENTS ?= deployments/31337.json

build:
	forge build

test:
	forge test

export-abi:
	chmod +x scripts/export-abi.sh
	./scripts/export-abi.sh

deploy-anvil:
	forge script script/WriteDeployment.s.sol:WriteDeployment \
		--rpc-url $(RPC_URL) \
		--private-key $(ANVIL_KEY) \
		--broadcast \
		-vvv
	$(MAKE) export-abi

anvil:
	anvil

backend:
	cd backend && DEPLOYMENTS_PATH=../deployments/31337.json ABI_DIR=../frontend/src/abi go run ./cmd/server

frontend:
	cd frontend && npm run dev

dev:
	@echo "Terminal 1: make anvil"
	@echo "Terminal 2: make deploy-anvil"
	@echo "Terminal 3: make -j2 backend frontend"
