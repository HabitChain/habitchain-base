# 🔗 HabitChain - Stake on Yourself

**Build habits with real skin in the game** 💪

HabitChain is a blockchain dApp that turns self-discipline into a financial commitment. Users lock ETH on their habits, complete daily check-ins, and earn back their stake plus yield when successful. If they fail, the locked funds are slashed to the protocol treasury.

## 🎯 One-liner

**Habits with real consequences. Real rewards.**

## 📋 Features

### Core Functionality

- **💰 Deposit ETH**: Fund your account with ETH to stake on habits
- **📝 Create Habits**: Create habits with custom names and stake amounts
- **✅ Daily Check-ins**: Self-attested daily check-ins to maintain habits
- **🎁 Yield Generation**: Your staked ETH earns yield through Aave V3 integration
- **⚖️ Settlement**: Force settle habits to either reclaim stake + yield (success) or lose to treasury (failure)
- **🏦 Treasury**: Track protocol statistics and slashed funds

### DeFi Integration

- **Aave V3**: All staked ETH is automatically deposited into Aave to earn yield
- **WETH Wrapping**: Automatic ETH ↔ WETH conversion for Aave compatibility
- **Real Yields**: Users earn actual DeFi yields on their committed funds

### UI/UX

- **OnChainKit**: Full integration with Coinbase's OnChainKit for seamless wallet management
- **Base Network**: Deployed on Base for low fees and fast transactions
- **Real-time Updates**: Live balance tracking and habit status updates
- **Responsive Design**: Modern, mobile-friendly interface built with Next.js and DaisyUI

## 🏗️ Tech Stack

- **Smart Contracts**: Solidity, Foundry
- **Frontend**: Next.js 14 (App Router), TypeScript, TailwindCSS, DaisyUI
- **Web3**: OnChainKit, RainbowKit, Wagmi, Viem
- **DeFi**: Aave V3 Protocol
- **Network**: Base, Base Sepolia
- **Testing**: Foundry (with forked Base mainnet)

## 🚀 Quick Start

### Prerequisites

- Node.js >= v20.18.3
- Yarn (v1 or v2+)
- Git
- Foundry

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd habitchain-base
```

2. Install dependencies:

```bash
yarn install
```

3. Set up environment variables:

```bash
# In packages/nextjs/.env.local
NEXT_PUBLIC_ONCHAINKIT_API_KEY=your_onchainkit_api_key
NEXT_PUBLIC_ALCHEMY_API_KEY=your_alchemy_api_key
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_walletconnect_project_id

# In packages/foundry/.env (optional for deployment)
BASESCAN_API_KEY=your_basescan_api_key
BASE_RPC_URL=https://mainnet.base.org
```

### Local Development

1. **Start local blockchain** (with Base fork):

```bash
yarn fork
```

2. **Deploy contracts** (in a new terminal):

```bash
yarn deploy
```

3. **Start frontend** (in a new terminal):

```bash
yarn start
```

4. Visit `http://localhost:3000`

### Testing

Run all tests with forked Base network:

```bash
cd packages/foundry
BASE_RPC_URL=https://mainnet.base.org forge test -vv
```

Run specific test:

```bash
BASE_RPC_URL=https://mainnet.base.org forge test --match-test testFullUserFlow -vvv
```

## 📐 Architecture

### Smart Contracts

#### HabitChain.sol

The main protocol contract with the following functionality:

**Core Functions:**

- `deposit()` - Deposit ETH into the protocol
- `withdraw(uint256 amount)` - Withdraw available ETH
- `createHabit(string name, uint256 stakeAmount)` - Create a new habit
- `checkIn(uint256 habitId)` - Perform daily check-in
- `forceSettle(uint256 habitId, bool success)` - Settle a habit (testing only)

**Aave Integration:**

- Automatically wraps ETH to WETH
- Supplies WETH to Aave V3 Pool
- Tracks aWETH (yield-bearing tokens)
- Withdraws from Aave on settlement

**View Functions:**

- `getUserBalance(address user)` - Get user's available balance
- `getHabit(uint256 habitId)` - Get habit details
- `getUserHabits(address user)` - Get all habit IDs for a user
- `getTreasuryBalance()` - Get protocol treasury balance

### Frontend Architecture

```
app/
├── page.tsx                    # Main dashboard
├── treasury/page.tsx           # Treasury statistics
└── debug/                      # Contract debugging (Scaffold-ETH)

components/
├── habitchain/
│   ├── Dashboard.tsx           # Main user dashboard
│   ├── CreateHabitModal.tsx    # Habit creation modal
│   ├── DepositModal.tsx        # ETH deposit modal
│   ├── WithdrawModal.tsx       # ETH withdrawal modal
│   ├── HabitCard.tsx           # Individual habit display
│   └── SettlementButton.tsx    # Force settlement UI
└── scaffold-eth/               # Reusable Web3 components
```

## 🔧 Configuration

### Network Configuration

Edit `packages/nextjs/scaffold.config.ts`:

```typescript
const scaffoldConfig = {
  targetNetworks: [chains.baseSepolia, chains.base],
  pollingInterval: 30000,
  // ... other config
};
```

### Aave V3 Addresses

Configured in `packages/foundry/script/DeployHabitChain.s.sol`:

**Base Mainnet (Chain ID: 8453)**

- Pool: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- WETH: `0x4200000000000000000000000000000000000006`
- aWETH: `0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7`

**Base Sepolia (Chain ID: 84532)**

- Pool: `0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b`
- WETH: `0x4200000000000000000000000000000000000006`
- aWETH: `0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1`

## 🎮 User Flow

### Complete Prototype Flow

1. **Connect Wallet** - Use RainbowKit to connect your Web3 wallet
2. **Deposit ETH** - Fund your account with ETH (minimum 0.001 ETH per habit)
3. **Create Habits** - Create habits with names and stake amounts
4. **Daily Check-ins** - Check in once per day for each active habit
5. **Settlement** - After habit period, force settle:
   - ✅ Success → Receive stake + yield earned from Aave
   - ❌ Failed → Stake + yield goes to protocol treasury
6. **Withdraw** - Withdraw your available balance anytime

## 📊 Protocol Statistics

View protocol-wide statistics on the Treasury page:

- Total treasury balance (from slashed habits)
- Total yield generated across all habits
- Success rate (% of habits completed successfully)
- Historical list of all slashed and settled habits

## 🧪 Testing Strategy

### Test Coverage

The test suite covers:

- ✅ Deposit and withdrawal functionality
- ✅ Habit creation with Aave integration
- ✅ Daily check-in mechanics with time validation
- ✅ Successful settlement (stake + yield returned)
- ✅ Failed settlement (slash to treasury)
- ✅ Full user flow (deposit → create 2 habits → check-in one → settle both)
- ✅ Multi-user scenarios
- ✅ Access control (users can't interact with others' habits)
- ✅ Edge cases (minimum stake, empty names, insufficient balance)
- ✅ Treasury management

### Forked Network Testing

All tests run against a forked Base mainnet to interact with real Aave V3 contracts:

```bash
BASE_RPC_URL=https://mainnet.base.org forge test
```

This ensures:

- Real Aave protocol integration
- Accurate yield calculations
- Production-like behavior

## 📦 Deployment

### Deploy to Base Sepolia

1. Set up deployer keystore:

```bash
cd packages/foundry
yarn generate
```

2. Deploy:

```bash
yarn deploy --network baseSepolia
```

3. Verify on Basescan:

```bash
forge verify-contract <CONTRACT_ADDRESS> HabitChain \
  --chain-id 84532 \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
    0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b \
    0x4200000000000000000000000000000000000006 \
    0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1 \
    <TREASURY_ADDRESS>)
```

### Deploy to Base Mainnet

Follow same steps but use `--network base`

## 🔮 Roadmap

### Current (Prototype)

- ✅ Core habit creation and check-in
- ✅ Aave V3 yield integration
- ✅ Basic settlement mechanism
- ✅ Treasury tracking
- ✅ OnChainKit integration

### Future Enhancements

**Phase 1: Production**

- [ ] Automated settlement at midnight UTC
- [ ] Time zone customization
- [ ] Enhanced yield accounting
- [ ] Gas optimizations

**Phase 2: Social Features**

- [ ] Group mode (redistribute slashed funds to successful group members)
- [ ] Leaderboards and achievements
- [ ] Social sharing and accountability

**Phase 3: Advanced Economics**

- [ ] Sponsored campaigns (companies fund extra rewards)
- [ ] Protocol-funded campaigns from treasury
- [ ] Multi-token support (USDC, DAI)
- [ ] Yield boosters for long-term habits

**Phase 4: Governance**

- [ ] DAO governance for treasury management
- [ ] Community-voted campaigns
- [ ] Protocol parameter adjustments

## 🎯 Design Philosophy

### Self-Accountability

- Habits are self-attested with no off-chain validation
- Users can only harm themselves through dishonesty
- This mirrors traditional habit tracking apps like Habitica
- Focus is on personal integrity, not surveillance

### Real Consequences

- Financial commitment creates genuine motivation
- Loss aversion psychology (fear of losing money)
- Immediate feedback through daily check-ins
- Transparent, automated enforcement via smart contracts

### Sustainable Economics

- Treasury grows from slashed habits
- Can fund campaigns and platform development
- Users earn DeFi yields on committed capital
- Network effects: More users = larger treasury = better campaigns

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Built with [Scaffold-ETH 2](https://scaffoldeth.io)
- Powered by [Aave V3](https://aave.com)
- UI components from [OnChainKit](https://onchainkit.xyz)
- Deployed on [Base](https://base.org)

## 📞 Support

- Documentation: See HIGH_LEVEL_VIEW.md and LIQUIDITY.md
- Issues: GitHub Issues
- Community: [Discord/Telegram link]

---

**Made with ❤️ for the Base Buildathon**

_Stake on yourself. Build better habits. Earn real rewards._
