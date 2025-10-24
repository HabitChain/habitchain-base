# Base Testnet Deployment - Quick Start Guide

This guide shows you how to deploy HabitChain to Base Sepolia testnet and configure the frontend to use it by default.

## Prerequisites

- Node.js 20+ and pnpm installed
- Foundry installed (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- A wallet with Base Sepolia ETH ([Get testnet ETH](https://www.coinbase.com/faucets))
- Your wallet's private key

## Step 1: Clone and Install

```bash
git clone <your-repo>
cd habitchain-base
pnpm install
```

## Step 2: Set Up Environment Variables

Create `packages/foundry/.env`:

```bash
# Your deployer private key (WITHOUT 0x prefix)
DEPLOYER_PRIVATE_KEY=your_private_key_here_without_0x

# Optional: For contract verification on BaseScan
BASESCAN_API_KEY=your_basescan_api_key_here
```

**⚠️ IMPORTANT**: 
- Never commit your `.env` file (it's in `.gitignore`)
- Remove the `0x` prefix from your private key
- Keep this file secure!

## Step 3: Compile Contracts

```bash
pnpm compile
```

This will compile the HabitChain smart contract and generate ABIs.

## Step 4: Deploy to Base Sepolia

```bash
pnpm deploy:testnet
```

This single command will:
1. Deploy HabitChain to Base Sepolia
2. Automatically generate TypeScript ABIs
3. Update the frontend with the deployed contract address

You should see output like:
```
🚀 Deploying DeployHabitChain.s.sol to baseSepolia...
📝 Using private key from DEPLOYER_PRIVATE_KEY environment variable

HabitChain deployed at: 0x1234567890abcdef...
Treasury address: 0x...
Aave Pool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b
WETH: 0x4200000000000000000000000000000000000006
aWETH: 0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1

✅ Deployment successful!
📝 Generating TypeScript ABIs...
📝 Updated TypeScript contract definition file on packages/nextjs/contracts/deployedContracts.ts

✅ All done!
```

## Step 5: Test the Frontend Locally

```bash
pnpm start
```

Visit `http://localhost:3000` and:
- Connect your wallet (switch to Base Sepolia network)
- You should see the HabitChain dashboard
- Try depositing some testnet ETH and creating a habit

## Step 6: Deploy Frontend to Production

### Option A: Deploy to Vercel

```bash
# Login to Vercel (first time only)
pnpm vercel:login

# Deploy
pnpm vercel
```

### Option B: Deploy to Cloudflare Pages

```bash
pnpm deploy:cloudflare
```

## What Was Pre-Configured

The following configuration changes were already made:

### 1. Frontend Network Configuration
`packages/nextjs/scaffold.config.ts`:
```typescript
targetNetworks: [chains.baseSepolia]  // Changed from [chains.hardhat, ...]
```

### 2. Deployment Scripts
- Added `pnpm deploy:pk` - Deploy using private key from env
- Added `pnpm deploy:testnet` - Quick deploy to Base Sepolia

### 3. Automatic ABI Generation
The deployment script automatically updates:
- `packages/nextjs/contracts/deployedContracts.ts`

This means your frontend immediately knows about your deployed contract!

## Verification (Optional)

To verify your contract on BaseScan:

```bash
# Make sure BASESCAN_API_KEY is set in your .env
pnpm verify --network baseSepolia
```

## Troubleshooting

### "DEPLOYER_PRIVATE_KEY environment variable is not set"
- Make sure you created `packages/foundry/.env`
- Check that your private key is in the file (without `0x` prefix)
- Run `source packages/foundry/.env` if using a Unix shell

### "Insufficient funds for gas"
- Get more Base Sepolia ETH from the [Base Faucet](https://www.coinbase.com/faucets)
- You need ~0.01 ETH for deployment

### "Network 'baseSepolia' not found"
- This shouldn't happen, but check that `packages/foundry/foundry.toml` has:
```toml
baseSepolia = "https://sepolia.base.org"
```

### Frontend shows "No contract found"
- Make sure the deployment completed successfully
- Check that `packages/nextjs/contracts/deployedContracts.ts` has an entry for chain ID `84532` (Base Sepolia)
- Restart the frontend: `pnpm start`

## Next Steps

1. **Test Your Contract**: Try all the features in the testnet
2. **Get Feedback**: Share the testnet deployment with users
3. **Monitor**: Watch contract activity on [BaseScan Sepolia](https://sepolia.basescan.org/)
4. **Prepare for Mainnet**: See `DEPLOYMENT.md` for mainnet deployment guide

## Full Documentation

- [Complete Deployment Guide](./DEPLOYMENT.md)
- [Architecture Overview](./AGENTS.md)
- [High Level Vision](./HIGH_LEVEL_VIEW.md)

## Security Reminders

- ✅ `.env` is in `.gitignore` - never commit it!
- ✅ Use environment variables in production (Vercel, GitHub Secrets, etc.)
- ✅ Test thoroughly on testnet before mainnet
- ✅ Consider getting an audit before deploying to mainnet with real funds

---

**That's it!** You now have HabitChain deployed to Base Sepolia testnet with a frontend configured to use it by default. 🎉

