# HabitChain Deployment Guide

## Prerequisites

1. **Foundry** installed and configured
2. **Node.js** and **Yarn** installed
3. **Wallet** with funds on Base Sepolia or Base Mainnet
4. **API Keys**:
   - Basescan API key for contract verification
   - Alchemy or Infura RPC endpoint (optional, can use public RPCs)

## Local Testing (Forked Base)

### 1. Fork Base Mainnet Locally

```bash
cd packages/foundry

# Start Anvil with Base mainnet fork
anvil --fork-url https://mainnet.base.org --chain-id 31337
```

### 2. Deploy to Local Fork

In a new terminal:

```bash
cd packages/foundry

# Deploy HabitChain
yarn deploy
```

### 3. Run Tests

```bash
# Run all tests against forked Base
BASE_RPC_URL=https://mainnet.base.org forge test -vv

# Run specific test with verbose output
BASE_RPC_URL=https://mainnet.base.org forge test --match-test testFullUserFlow -vvv
```

### 4. Start Frontend

```bash
# In project root
yarn start
```

Visit `http://localhost:3000` and connect with a test wallet.

## Base Sepolia Testnet Deployment

### 1. Get Testnet ETH

Get Base Sepolia ETH from:
- [Base Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- [Alchemy Faucet](https://sepoliafaucet.com/)

### 2. Set Up Deployer Account

```bash
cd packages/foundry

# Generate a new keystore (if you don't have one)
yarn generate

# Or import existing private key
yarn import
```

The default keystore is `scaffold-eth-default` with no password.

### 3. Configure Environment

Create `packages/foundry/.env`:

```bash
# Base Sepolia RPC (or use public RPC)
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# For contract verification
BASESCAN_API_KEY=your_basescan_api_key_here

# Deployer account (optional, defaults to scaffold-eth-default)
ETH_KEYSTORE_ACCOUNT=scaffold-eth-default
```

### 4. Deploy to Base Sepolia

```bash
cd packages/foundry

# Deploy HabitChain to Base Sepolia
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url baseSepolia \
  --broadcast \
  --verify
```

Or using the yarn command:

```bash
yarn deploy --network baseSepolia
```

### 5. Verify Deployment

After deployment, you'll see:
```
HabitChain deployed at: 0x...
Treasury address: 0x...
Aave Pool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b
WETH: 0x4200000000000000000000000000000000000006
aWETH: 0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1
```

Check on Basescan:
- Contract: https://sepolia.basescan.org/address/CONTRACT_ADDRESS
- Transactions: https://sepolia.basescan.org/address/CONTRACT_ADDRESS#internaltx

### 6. Update Frontend

The deployment automatically updates `packages/nextjs/contracts/deployedContracts.ts`.

Restart the frontend:
```bash
yarn start
```

## Base Mainnet Deployment

⚠️ **WARNING**: Deploying to mainnet involves real funds. Ensure contracts are audited and thoroughly tested.

### 1. Get Mainnet ETH

Ensure your deployer wallet has sufficient ETH on Base Mainnet for:
- Contract deployment (~0.01-0.05 ETH)
- Gas for transactions
- Initial protocol testing

### 2. Configure Environment

Update `packages/foundry/.env`:

```bash
# Base Mainnet RPC
BASE_RPC_URL=https://mainnet.base.org

# Or use Alchemy/Infura
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# For contract verification
BASESCAN_API_KEY=your_basescan_api_key_here

# Use a secure keystore for mainnet
ETH_KEYSTORE_ACCOUNT=my-secure-keystore
```

### 3. Security Checklist

Before mainnet deployment:

- [ ] Smart contracts audited by professional auditors
- [ ] All tests passing on forked mainnet
- [ ] Gas optimizations implemented
- [ ] Emergency pause mechanism tested
- [ ] Treasury address confirmed and secure
- [ ] Multi-sig wallet for treasury (recommended)
- [ ] Rate limiting and caps on deposits
- [ ] Frontend security review completed

### 4. Deploy to Base Mainnet

```bash
cd packages/foundry

# Deploy HabitChain to Base Mainnet
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base \
  --broadcast \
  --verify \
  --slow
```

The `--slow` flag adds delays between transactions to avoid RPC rate limits.

### 5. Post-Deployment Steps

1. **Verify Contract on Basescan**:
   - Visit Basescan
   - Check that contract source is verified
   - Review constructor arguments

2. **Test Basic Functions**:
   ```bash
   # Deposit test amount
   cast send CONTRACT_ADDRESS "deposit()" \
     --value 0.01ether \
     --rpc-url $BASE_RPC_URL \
     --private-key $PRIVATE_KEY
   
   # Check balance
   cast call CONTRACT_ADDRESS "getUserBalance(address)" YOUR_ADDRESS \
     --rpc-url $BASE_RPC_URL
   ```

3. **Initialize Protocol**:
   - Deposit initial liquidity for testing
   - Create test habits
   - Verify Aave integration works

4. **Monitor Contract**:
   - Set up monitoring (Tenderly, OpenZeppelin Defender)
   - Monitor treasury balance
   - Track user activity
   - Watch for anomalies

5. **Frontend Deployment**:
   ```bash
   # Update frontend with mainnet contract
   yarn start
   
   # Or deploy to Vercel
   yarn vercel
   ```

## Verification

### Manual Verification

If automatic verification fails:

```bash
cd packages/foundry

# Get constructor arguments
cast abi-encode "constructor(address,address,address,address)" \
  AAVE_POOL_ADDRESS \
  WETH_ADDRESS \
  AWETH_ADDRESS \
  TREASURY_ADDRESS

# Verify on Basescan
forge verify-contract \
  --chain-id 8453 \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
    0xA238Dd80C259a72e81d7e4664a9801593F98d1c5 \
    0x4200000000000000000000000000000000000006 \
    0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7 \
    TREASURY_ADDRESS) \
  CONTRACT_ADDRESS \
  contracts/HabitChain.sol:HabitChain \
  --etherscan-api-key $BASESCAN_API_KEY
```

## Contract Addresses

### Base Sepolia Testnet

- **Aave V3 Pool**: `0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b`
- **WETH**: `0x4200000000000000000000000000000000000006`
- **aWETH**: `0x9c8Aa5E801E3E072e0eD1BE4A2dE836E20aCABd1`

### Base Mainnet

- **Aave V3 Pool**: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- **WETH**: `0x4200000000000000000000000000000000000006`
- **aWETH**: `0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7`

## Troubleshooting

### "Insufficient funds for gas"
- Ensure deployer wallet has enough ETH
- Check RPC endpoint is correct
- Try increasing gas price

### "Contract verification failed"
- Ensure compiler version matches (0.8.20)
- Check constructor arguments are correct
- Try manual verification process above

### "Aave deposit fails"
- Verify Aave Pool address is correct for network
- Ensure WETH address is correct
- Check contract has ETH to wrap

### "Tests fail on fork"
- Ensure BASE_RPC_URL is set and accessible
- Try different RPC endpoint
- Check fork block number is recent

### "Frontend doesn't show contract"
- Verify `deployedContracts.ts` is updated
- Check network in `scaffold.config.ts`
- Restart frontend: `yarn start`

## Gas Optimization Tips

1. **Batch Operations**: Combine multiple actions in one transaction
2. **Use L2**: Base has much lower gas costs than Ethereum mainnet
3. **Optimize Storage**: Minimize SSTORE operations
4. **Event Indexing**: Use indexed parameters sparingly

## Security Best Practices

1. **Treasury Management**:
   - Use multi-sig wallet (Gnosis Safe)
   - Set up timelock for withdrawals
   - Regular audits of treasury balance

2. **Access Control**:
   - Verify only treasury can withdraw treasury funds
   - Test all access control modifiers
   - Monitor for unauthorized access attempts

3. **Monitoring**:
   - Set up alerts for large deposits
   - Monitor settlement patterns
   - Track unusual activity

4. **Emergency Procedures**:
   - Have pause mechanism ready
   - Plan for contract upgrades (if needed)
   - Maintain contact with users

## Support

For deployment issues:
- Check Scaffold-ETH 2 docs: https://docs.scaffoldeth.io
- Foundry Book: https://book.getfoundry.sh
- Base docs: https://docs.base.org

---

**Remember**: Always test thoroughly on testnet before mainnet deployment!

