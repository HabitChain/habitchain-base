# 🔗 HabitChain - Stake on Yourself

**Build habits with real skin in the game** 💪

> A DeFi-powered habit tracking protocol built on Base with Aave V3 yield integration.

HabitChain turns self-discipline into financial commitment. Users stake ETH on their habits, earn yield through Aave, and either reclaim their stake + yield (success) or lose it to the treasury (failure).

---

## 📚 Documentation

- **[HABITCHAIN_README.md](./HABITCHAIN_README.md)** - Complete product documentation
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Deployment guide for Base networks
- **[IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)** - Technical implementation details
- **[HIGH_LEVEL_VIEW.md](./HIGH_LEVEL_VIEW.md)** - Product vision and roadmap
- **[LIQUIDITY.md](./LIQUIDITY.md)** - Aave V3 integration strategy

---

## 🚀 Quick Start

```bash
# Install dependencies
yarn install

# Start local blockchain (forked Base)
yarn fork

# Deploy contracts (in new terminal)
yarn deploy

# Start frontend (in new terminal)
yarn start
```

Visit `http://localhost:3000` to use HabitChain!
yar

### Time Travel Commands (for testing)

When running the forked local blockchain, you can use these commands to manipulate time:

```bash
# Skip forward 1 day (86400 seconds) and mine a block
yarn skip

# Mine a single block (without time advancement)
yarn mine
```

These are useful for testing time-based functionality like habit check-ins and deadline expiration.

### Cursor Slash Commands

- `/happy` - Happy path testing

---

## 🏗 Built With Scaffold-ETH 2

<h4 align="center">
  <a href="https://docs.scaffoldeth.io">Scaffold-ETH Docs</a> |
  <a href="https://scaffoldeth.io">Scaffold-ETH Website</a>
</h4>

⚙️ Tech Stack: NextJS, RainbowKit, Foundry, Wagmi, Viem, TypeScript, OnChainKit

- ✅ **Contract Hot Reload**: Your frontend auto-adapts to your smart contract as you edit it.
- 🪝 **[Custom hooks](https://docs.scaffoldeth.io/hooks/)**: Collection of React hooks wrapper around [wagmi](https://wagmi.sh/) to simplify interactions with smart contracts with typescript autocompletion.
- 🧱 [**Components**](https://docs.scaffoldeth.io/components/): Collection of common web3 components to quickly build your frontend.
- 🔥 **Burner Wallet & Local Faucet**: Quickly test your application with a burner wallet and local faucet.
- 🔐 **Integration with Wallet Providers**: Connect to different wallet providers and interact with the Ethereum network.

![Debug Contracts tab](https://github.com/scaffold-eth/scaffold-eth-2/assets/55535804/b237af0c-5027-4849-a5c1-2e31495cccb1)

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Quickstart

To get started with Scaffold-ETH 2, follow the steps below:

1. Install dependencies if it was skipped in CLI:

```
cd my-dapp-example
yarn install
```

2. Run a local network in the first terminal:

```
yarn fork
```

This command starts a local Ethereum network using Foundry. The network runs on your local machine and can be used for testing and development. You can customize the network configuration in `packages/foundry/foundry.toml`.

3. On a second terminal, deploy the test contract:

```
yarn deploy
```

This command deploys a test smart contract to the local network. The contract is located in `packages/foundry/contracts` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `packages/foundry/script` to deploy the contract to the network. You can also customize the deploy script.

4. On a third terminal, start your NextJS app:

```
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the `Debug Contracts` page. You can tweak the app config in `packages/nextjs/scaffold.config.ts`.

Run smart contract test with `yarn foundry:test`

- Edit your smart contracts in `packages/foundry/contracts`
- Edit your frontend homepage at `packages/nextjs/app/page.tsx`. For guidance on [routing](https://nextjs.org/docs/app/building-your-application/routing/defining-routes) and configuring [pages/layouts](https://nextjs.org/docs/app/building-your-application/routing/pages-and-layouts) checkout the Next.js documentation.
- Edit your deployment scripts in `packages/foundry/script`

## Documentation

Visit our [docs](https://docs.scaffoldeth.io) to learn how to start building with Scaffold-ETH 2.

To know more about its features, check out our [website](https://scaffoldeth.io).

## Contributing to Scaffold-ETH 2

We welcome contributions to Scaffold-ETH 2!

Please see [CONTRIBUTING.MD](https://github.com/scaffold-eth/scaffold-eth-2/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to Scaffold-ETH 2.
