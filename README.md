# USDK

实现一套**可控 Mint / Burn** 的 ERC-20 稳定币（`USDK`），以及基于超额抵押的 `**USDKEngine`** 借贷与清算逻辑。代币发行由单一 `owner` 管控，链上引擎负责在抵押充足时增发、在还款或清算时销毁。

## 功能概览


| 模块                                   | 职责                                                                           |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| `[USDK](src/USDK.sol)`               | 标准 ERC-20；仅 `owner` 可 `mint` / `burn`；支持 `transfer`、`approve`、`transferFrom` |
| `[USDKEngine](src/USDKEngine.sol)`   | 多抵押品存取、铸造/偿还债务、健康因子校验、Chainlink 定价、清算                                        |
| `[IERC20](src/interface/IERC20.sol)` | 最小 ERC-20 接口（参考 [EIP-20](https://eips.ethereum.org/EIPS/eip-20)）             |


### USDK（稳定币层）

- **权限化供应**：`mint` / `burn` 受 `onlyOwner` 限制，避免任意地址增发。
- **标准转账**：18 位小数，完整实现 `name`、`symbol`、`balanceOf`、`transfer`、`approve` 等。
- **所有权转移**：`changeOwner` 可将铸币权限交给新地址（部署后通常将 `owner` 设为 `USDKEngine` 合约地址）。

### USDKEngine（抵押与清算层）

- **多抵押品**：构造函数配置抵押代币、Chainlink `priceFeed` 与清算阈值（`liquidationThreshold`，单位 1e4）。
- **存取与铸还**：`deposit` / `redeem`、`mint` / `burn`，以及组合操作 `depositAndMint`、`redeemAndBurn`。
- **健康因子**：抵押品 USD 价值（含清算阈值折扣）÷ 债务；低于 `1e18` 时禁止增债或赎回导致恶化。
- **清算**：健康账户不可清算；单次最多清偿账户债务的 50%；清算人支付 USDK 并获得带 **10%** 奖励的抵押品。
- **安全**：`ReentrancyGuard`、价格必须为正且更新时间在 **2 小时**内。

## 架构

```mermaid
flowchart LR
    User[用户 / 清算人]
    Engine[USDKEngine]
    Token[USDK]
    Collateral[抵押 ERC-20]
    Oracle[Chainlink Aggregator]

    User -->|存入抵押品| Engine
    User -->|mint / burn 债务| Engine
    Engine -->|mint / burn| Token
    Engine -->|持有抵押品| Collateral
    Engine -->|latestRoundData| Oracle
    User -->|transfer USDK| Token
```



部署建议：

1. 部署 `USDK(name, symbol, deployer)`。
2. 部署 `USDKEngine(usdk, collateralTokens, priceFeeds, liquidationThresholds)`。
3. 调用 `USDK.changeOwner(address(engine))`，使只有引擎能增发/销毁。

## 核心公式

**健康因子**（`healthFactor >= 1e18` 为安全）：

```
healthFactor = Σ(抵押数量 × USD 单价 × liquidationThreshold / 1e4) / 债务（USDK）
```

无债务时健康因子为 `type(uint256).max`。

**清算奖励**：清偿债务的 10%（`LIQUIDATION_BONUS = 1000`，精度 `1e4`）。

## 项目结构

```
usdk/
├── src/
│   ├── USDK.sol              # ERC-20 稳定币
│   ├── USDKEngine.sol        # 抵押借贷引擎
│   └── interface/IERC20.sol
├── test/
│   ├── unit/                 # 单元测试
│   ├── invariant/            # USDK 状态不变量（总供应 = 余额之和）
│   └── mock/
├── lib/                      # Git 子模块：forge-std、OpenZeppelin、Chainlink
├── foundry.toml
└── .github/workflows/test.yml
```

## 技术栈

- [Foundry](https://book.getfoundry.sh/) — 编译、测试、格式化
- Solidity **0.8.24**
- [OpenZeppelin](https://github.com/openzeppelin/openzeppelin-contracts) — `ReentrancyGuard`
- [Chainlink](https://github.com/smartcontractkit/chainlink-evm) — `AggregatorV3Interface` 价格源

## 快速开始

### 环境要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)（`forge`、`cast`）
- Git（用于拉取子模块）

### 克隆与依赖

```bash
git clone <your-repo-url> usdk
cd usdk
git submodule update --init --recursive
```

若子模块未初始化，也可执行：

```bash
forge install
```

### 编译

```bash
forge build
```

### 测试

```bash
# 全部测试（verbose）
forge test -vvv

# 仅 USDK 单元测试
forge test --match-path test/unit/USDKUnitTest.t.sol -vvv

# USDK 不变量测试（fuzz + handler）
forge test --match-path test/invariant/ -vvv

# 格式化检查（与 CI 一致）
forge fmt --check
```

当前 `test/unit/USDKEngineUnitTest.t.sol` 仍为占位骨架，完整引擎测试待补充；`USDK` 单元测试与不变量测试可独立运行。

### 覆盖率（可选）

```bash
forge coverage
```

## 主要合约 API（摘要）

### USDK


| 函数                                | 说明                  |
| --------------------------------- | ------------------- |
| `mint(address to, uint256 value)` | `onlyOwner`，增发      |
| `burn(uint256 value)`             | `onlyOwner`，销毁调用者余额 |
| `changeOwner(address newOwner)`   | 转移铸币权限              |


### USDKEngine


| 函数                                                      | 说明              |
| ------------------------------------------------------- | --------------- |
| `deposit` / `redeem`                                    | 存入 / 取回抵押品      |
| `mint` / `burn`                                         | 增发 / 偿还 USDK 债务 |
| `depositAndMint` / `redeemAndBurn`                      | 组合操作            |
| `liquidate(account, collateralToken, debtToCover)`      | 清算不健康账户         |
| `getHealthFactor` / `getUserDebt` / `getUserCollateral` | 只读查询            |


## 测试说明

- **单元测试** `[test/unit/USDKUnitTest.t.sol](test/unit/USDKUnitTest.t.sol)`：初始化、权限、mint/burn、零地址、allowance、`transferFrom`、fuzz 转账等。
- **不变量测试** `[test/invariant/USDKInvariant.t.sol](test/invariant/USDKInvariant.t.sol)`：在随机 mint/burn/transfer 序列下，断言 `sum(balance) == totalSupply` 且与 ghost 计数一致。
- **引擎测试**：`[test/unit/USDKEngineUnitTest.t.sol](test/unit/USDKEngineUnitTest.t.sol)` 待实现（需 Mock 抵押品与 Chainlink 喂价）。

## CI

推送或 PR 时在 GitHub Actions 中执行：

1. `forge fmt --check`
2. `forge build --sizes`
3. `forge test -vvv`

见 `[.github/workflows/test.yml](.github/workflows/test.yml)`。

## 设计说明与局限

- **中心化铸币权**：`USDK` 的 `owner` 拥有绝对增发权，适合模拟机构稳定币，需链下治理与多签等机制才能接近生产要求。
- **引擎即 minter**：生产部署应将 `USDK.owner` 设为 `USDKEngine`，用户只能通过引擎路径产生债务代币。
- **价格依赖**：依赖 Chainlink 喂价新鲜度（`MAX_DELAY = 2 hours`），未涵盖预言机操纵的完整防御。
- **练习范围**：未实现暂停、黑名单、升级代理、多签 `owner` 等常见企业功能。

## 作者

SongKai

## License

MIT