# 🚀 Getting Started with HabitChain

Welcome to HabitChain! This guide will help you get up and running quickly.

## What is HabitChain?

HabitChain is a DeFi-powered habit tracking dApp where you:
1. **Deposit ETH** to fund your habits
2. **Create habits** by staking ETH (your funds earn yield via Aave V3)
3. **Check in daily** to maintain your commitment
4. **Settle habits** to either reclaim your stake + yield or lose it to the treasury

## Prerequisites

Make sure you have:
- Node.js v20.18.3 or higher
- Yarn (v1 or v2+)
- Git

## Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd habitchain-base

# Install dependencies
yarn install
```

## Running Locally

### Option 1: Quick Start (Recommended)

Open 3 terminals and run:

**Terminal 1 - Start blockchain:**
```bash
yarn chain
```
This starts a local Ethereum network using Anvil.

**Terminal 2 - Deploy contracts:**
```bash
yarn deploy
```
This deploys the HabitChain contract to your local network.

**Terminal 3 - Start frontend:**
```bash
yarn start
```
This starts the Next.js frontend at `http://localhost:3000`.

### Option 2: Forked Base Network (Advanced)

To test with real Aave contracts, fork Base mainnet:

**Terminal 1 - Fork Base:**
```bash
cd packages/foundry
anvil --fork-url https://mainnet.base.org --chain-id 31337
```

**Terminal 2 - Deploy:**
```bash
yarn deploy
```

**Terminal 3 - Start frontend:**
```bash
yarn start
```

## Using HabitChain

### 1. Connect Your Wallet

Visit `http://localhost:3000` and click "Connect Wallet" in the top right.

For local testing, use one of Anvil's test accounts:
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- This account has 10,000 ETH for testing

### 2. Deposit ETH

1. Click "💰 Deposit ETH"
2. Enter amount (e.g., 1 ETH)
3. Click "Deposit"
4. Confirm transaction in your wallet

Your deposited ETH is now available to stake on habits!

### 3. Create Your First Habit

1. Click "➕ Create New Habit"
2. Enter a habit name (e.g., "Morning Meditation")
3. Enter stake amount (minimum 0.001 ETH)
4. Click "Create Habit"

Your staked ETH is now:
- Locked in the habit
- Earning yield via Aave V3
- Waiting for your daily check-ins

### 4. Check In Daily

On your habit card:
1. Click "✓ Check In" once per day
2. Confirm the transaction
3. Come back tomorrow to check in again!

Note: You can only check in once every 24 hours.

### 5. Settle Your Habit (Testing)

When you're ready to test settlement:

1. Click "Force Settle (Testing)"
2. Choose your result:
   - "✓ Success" - Get back your stake + yield earned
   - "✗ Failed" - Lose your stake to the treasury
3. Confirm transaction

In production, settlement would happen automatically at midnight UTC.

### 6. Withdraw Your Rewards

After successful settlement:
1. Click "💸 Withdraw ETH"
2. Enter amount or click "MAX"
3. Click "Withdraw"
4. ETH is sent back to your wallet!

## Exploring the dApp

### Dashboard (`/`)
- View your available balance
- See all your habits (active and settled)
- Deposit, withdraw, and create habits

### Treasury (`/treasury`)
- View total treasury balance
- See protocol statistics
- Check success rate
- Browse slashed and settled habits

### Debug Contracts (`/debug`)
- Interact directly with contract functions
- View contract state
- Test edge cases
- Read events

## Running Tests

```bash
cd packages/foundry

# Run all tests (with Base fork)
BASE_RPC_URL=https://mainnet.base.org forge test -vv

# Run specific test
BASE_RPC_URL=https://mainnet.base.org forge test --match-test testFullUserFlow -vvv

# Run without fork (faster but no real Aave)
forge test
```

## Common Issues

### "Insufficient funds for gas"
- Make sure you're using a funded test account
- Check you're connected to the local network

### "Transaction failed"
- Check you have enough deposited balance
- Ensure you're not trying to check in twice in 24 hours
- Verify the habit is still active (not settled)

### Frontend not loading
- Make sure all three terminals are running
- Check that port 3000 is not in use
- Try `yarn start --port 3001` to use a different port

### Contracts not deploying
- Make sure `yarn chain` is running first
- Check for any Foundry errors in the terminal
- Try `forge clean` and then `yarn deploy` again

## Next Steps

Ready to deploy to testnet? Check out [DEPLOYMENT.md](./DEPLOYMENT.md)!

Want to understand the architecture? Read [HABITCHAIN_README.md](./HABITCHAIN_README.md)!

Need help? Check the [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) for technical details.

## Tips for Testing

1. **Create Multiple Habits**: Test with 2-3 habits to see how they interact
2. **Test Settlement Flows**: Try both success and failure scenarios
3. **Check Treasury**: After failed settlements, check the treasury page
4. **Experiment with Amounts**: Try different stake amounts
5. **Time Travel**: Use `anvil_mine` to simulate time passing for check-ins

## Development Workflow

1. **Edit Smart Contracts**: `packages/foundry/contracts/HabitChain.sol`
2. **Run Tests**: `forge test`
3. **Deploy Locally**: `yarn deploy`
4. **Edit Frontend**: `packages/nextjs/app/` and `components/habitchain/`
5. **Frontend Auto-Reloads**: Changes appear immediately
6. **Contract Changes**: Need to redeploy with `yarn deploy`

## Useful Commands

```bash
# Clean build artifacts
forge clean

# Build contracts
forge build

# Test contracts
forge test

# Deploy contracts
yarn deploy

# Start frontend
yarn start

# Format code
yarn prettier

# Lint code
yarn lint
```

## Resources

- **Scaffold-ETH 2 Docs**: https://docs.scaffoldeth.io
- **Base Documentation**: https://docs.base.org
- **Aave V3 Docs**: https://docs.aave.com
- **OnChainKit**: https://onchainkit.xyz
- **Foundry Book**: https://book.getfoundry.sh

## Support

Having issues? Check:
1. This guide
2. [DEPLOYMENT.md](./DEPLOYMENT.md) for deployment issues
3. [HABITCHAIN_README.md](./HABITCHAIN_README.md) for feature questions
4. GitHub Issues for bugs

---

**Happy habit building! 🔗💪**

Stake on yourself and build better habits with real consequences and rewards!

