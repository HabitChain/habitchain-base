# AGENTS.md

## Project Overview

HabitChain is a DeFi-powered habit tracking protocol built on Base where users stake ETH on their habits. All staked funds are deposited into Aave V3 to earn yield. Users perform daily check-ins and either reclaim their stake + yield (success) or lose it to the protocol treasury (failure).

**Tech Stack**: Scaffold-ETH 2 (NextJS App Router, TypeScript, TailwindCSS, OnChainKit, RainbowKit, Wagmi, Viem) + Foundry for smart contracts.

## Common Commands

### Development Workflow

```bash
# Start local forked Base blockchain (terminal 1)
pnpm fork

# Start local forked Base blockchain with 3x faster mining (instant block mining)
pnpm fork:fast

# Deploy contracts (terminal 2) - have to use "run" for deploy
pnpm run deploy

# Start frontend dev server (terminal 3)
pnpm start
```

### Testing

```bash
# Run all Foundry tests with forked Base mainnet
pnpm test

# Run specific test with verbose output
cd packages/foundry
BASE_RPC_URL=https://mainnet.base.org forge test --match-test testFullUserFlow -vvv

# Run single test file
BASE_RPC_URL=https://mainnet.base.org forge test --match-path test/HabitChain.t.sol -vv
```

### Compilation & Type Checking

```bash
# Compile smart contracts (after contract changes)
pnpm compile

# Check frontend types (after frontend changes)
pnpm next:check-types

# Format code
pnpm format
```

### Time Manipulation (Local Fork Testing)

```bash
# Skip forward 1 day (86400 seconds) and mine a block
pnpm skip

# Mine a single block without advancing time
pnpm mine
```

### Deployment
 
Note: don't deploy to testnet or mainnet without asking first.
Local devnet is fine.

```bash
# Deploy to Base Sepolia using private key from env (recommended for CI/CD)
pnpm deploy:testnet
# or
pnpm deploy:pk --network baseSepolia

# Deploy using Foundry keystore (interactive)
pnpm deploy --network baseSepolia

# Deploy to Base mainnet
pnpm deploy:pk --network base
```

**Environment Setup for Private Key Deployment**:

Create `packages/foundry/.env`:
```bash
DEPLOYER_PRIVATE_KEY=your_private_key_without_0x_prefix
BASESCAN_API_KEY=your_basescan_api_key
ALCHEMY_API_KEY=your_alchemy_api_key
```

## Architecture

### Smart Contract: HabitChain.sol

**Location**: `packages/foundry/contracts/HabitChain.sol`

**Core Concepts**:

- All ETH deposits are wrapped to WETH and supplied to Aave V3 Pool
- User balances and staked funds are tracked as aWETH (yield-bearing tokens)
- Habits track the aWETH amount at creation time for accurate yield calculation
- Treasury balance also earns yield through Aave

**Key Functions**:

- `deposit()` - Wraps ETH → WETH → supplies to Aave → credits user aWETH balance
- `withdraw(uint256)` - Burns aWETH → withdraws WETH from Aave → unwraps to ETH
- `createHabit(string, uint256)` - Moves aWETH from user balance to habit stake
- `checkIn(uint256)` - Daily check-in (enforces ONE_DAY cooldown using block.timestamp)
- `forceSettle(uint256, bool)` - Testing-only function to settle habits

**Aave Integration**:

- Uses real Aave V3 contracts on Base (not mocked)
- WETH address: `0x4200000000000000000000000000000000000006` (Base canonical WETH)
- Base Mainnet Pool: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- Base Sepolia Pool: `0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b`

**State Variables**:

- `userBalances[address]` - User's available aWETH balance
- `treasuryBalance` - Treasury's aWETH balance (from slashed habits)
- `habits[uint256]` - Habit struct by ID
- `userHabits[address]` - Array of habit IDs per user

### Deployment Script

**Location**: `packages/foundry/script/DeployHabitChain.s.sol`

Handles network-specific Aave V3 addresses automatically based on chain ID (8453 = Base, 84532 = Base Sepolia, 31337 = local fork).

### Testing Strategy

**Location**: `packages/foundry/test/HabitChain.t.sol`

Tests run against a **forked Base mainnet** to interact with real Aave contracts. This is critical - do not mock Aave. The fork is set up in `setUp()` using `vm.createFork()` and requires `BASE_RPC_URL` environment variable.

**Key Test Patterns**:

- Use `vm.deal()` to fund test accounts
- Use `vm.startPrank(user)` / `vm.stopPrank()` for user context
- Use `vm.warp(block.timestamp + 1 days)` for time travel in tests
- Verify Aave integration by checking aWETH balances

### Frontend Architecture

**Location**: `packages/nextjs/`

**Key Files**:

- `app/page.tsx` - Main dashboard
- `components/habitchain/Dashboard.tsx` - Main UI component
- `components/habitchain/CreateHabitModal.tsx` - Habit creation
- `components/habitchain/HabitCard.tsx` - Individual habit display
- `scaffold.config.ts` - Network configuration (Base, Base Sepolia)

**Scaffold-ETH Hooks** (must use these for contract interactions):

- `useScaffoldReadContract` - Read contract state
- `useScaffoldWriteContract` - Write transactions (initialize with contract name, then call `writeContractAsync`)
- `useScaffoldEventHistory` - Listen to contract events

**Example Read**:

```typescript
const { data: balance } = useScaffoldReadContract({
  contractName: "HabitChain",
  functionName: "getUserBalance",
  args: [address],
});
```

**Example Write**:

```typescript
const { writeContractAsync } = useScaffoldWriteContract({
  contractName: "HabitChain",
});

await writeContractAsync({
  functionName: "deposit",
  value: parseEther("0.1"),
});
```

**Scaffold-ETH Components** (use these instead of custom implementations):

- `<Address address={...} />` - Display ETH addresses
- `<AddressInput value={...} onChange={...} />` - Input ETH addresses
- `<Balance address={...} />` - Display ETH/token balances
- `<EtherInput value={...} onChange={...} />` - Input ETH amounts with USD conversion

### Contract ABI Generation

After modifying smart contracts:

1. Run `pnpm compile` to generate new ABIs
2. Deployment automatically updates `packages/nextjs/contracts/deployedContracts.ts`
3. Frontend hooks auto-detect the new ABI structure
4. TypeScript types are auto-generated for type-safe contract interactions

## Important Development Notes

### Time Management

- Smart contracts use `block.timestamp` for time-based logic
- ONE_DAY constant = 1 days (86400 seconds)
- Check-ins enforce minimum 1-day gap using: `require(block.timestamp >= habit.lastCheckIn + ONE_DAY)`
- On local fork, use `pnpm skip` to advance time for testing

### User Workflow

1. Deposit ETH (becomes aWETH in Aave, tracked in userBalances)
2. Create habit (moves aWETH from userBalances to habit stake)
3. Check-in daily (updates lastCheckIn timestamp and checkInCount)
4. Force settle (testing) or auto-settle (future):
   - Success: aWETH + yield → user balance
   - Failure: aWETH + yield → treasury balance

### Testing Philosophy

- All tests MUST use forked Base mainnet (`BASE_RPC_URL` required)
- Never mock Aave contracts - test against real deployed contracts
- Use `vm.warp()` for time-based testing
- Test multi-user scenarios to ensure proper access control

## Project-Specific Rules from .cursorrules

1. **Check dev servers** - In one command, check if localhost 3000 and 8545 are running and if not, run `pnpm fork` and `pnpm start`. Check and run individually.
2. **Deploy contracts** - After contract changes, run `pnpm run deploy` to deploy the contract.
3. **Run `pnpm next:check-types`** after frontend changes (avoid `any` types)
4. **Run `pnpm compile`** after contract changes
5. **Update ABIs**: After contract updates, run compile and ensure frontend picks up new ABI
6. **No .md files** unless explicitly asked
7. **After contract updates**: compile → test → deploy

## Documentation References

- `HABITCHAIN_README.md` - Complete product documentation
- `DEPLOYMENT.md` - Deployment guide for Base networks
- `IMPLEMENTATION_SUMMARY.md` - Technical implementation details
- `HIGH_LEVEL_VIEW.md` - Product vision and roadmap
- `LIQUIDITY.md` - Aave V3 integration strategy
- `TESTING_HAPPY_PATH.md` - Browser testing guide

Please keep this document up to date
Don't create new .md files unless asked to.
