# HabitChain (Base)

HabitChain is a dApp that turns self‑discipline into a financial commitment.

Users lock funds on their own habit, complete daily check‑ins, and—if successful—reclaim their stake plus yield.  
If they fail, the locked fund is slashed to the protocol treasury (or, in groups, redistributed to successful peers).

The prototype proves one essential on‑chain action: **commit → check‑in → settle**

By adding real consequences and immediate feedback, HabitChain closes the “motivation gap”, aligning personal progress with tangible rewards.

## Details

- Submission: https://devfolio.co/projects/habitchain-03ee
- Network: Base Sepolia Testnet
- Address: [0x6F7DB63504902906B48193bB61771dF5c67eC2C2](https://sepolia.basescan.org/address/0x6F7DB63504902906B48193bB61771dF5c67eC2C2)
- ABI: [https://github.com/HabitChain/habitchain-base/blob/2b86b7db15862e9a20ce2c2c4e2c461840feec26/packages/nextjs/contracts/deployedContracts.ts#L956](https://github.com/HabitChain/habitchain-base/blob/2b86b7db15862e9a20ce2c2c4e2c461840feec26/packages/nextjs/contracts/deployedContracts.ts#L956)
- Video (Pitch + Demo): [https://youtu.be/-MpjpKS_bgE](https://youtu.be/-MpjpKS_bgE)
- Prototype features working Aave V3 integration for yield generation

## Testing Instructions

1. Go to https://112f405c.habitchain-base.pages.dev/
2. Setup/connect wallet and get Base Sepolia ETH from a faucet
3. Deposit funds
4. Change the "Check-in Period" to 30 or 60 seconds for faster testing
5. Create two habits
6. Check-in one habit, but don't do the other
7. Wait the check-in period to pass and click on "Natural Settle" to settle the habits
8. Notice one habit slashed and the other kept active

Note: you might need to refresh the page in between some steps if the UI don't update
Note: currently there's no way to see the yield rewards, but the Aave integration is in place.

## Technology Stack

This project was bootstraped with [scaffold-eth-2](https://github.com/scaffold-eth/scaffold-eth-2) and includes the following:

- [Next.js](https://nextjs.org/) (v15.2.4) - React framework for the frontend
- [React](https://react.dev/) (v19.0.0) - UI library
- [TypeScript](https://www.typescriptlang.org/) (v5) - Type-safe JavaScript
- [Foundry](https://getfoundry.sh/) - Ethereum smart contract development framework
- [Solidity](https://soliditylang.org/) - Smart contract language for EVM chains
- [RainbowKit](https://www.rainbowkit.com/) - Wallet connection library
- [Wagmi](https://wagmi.sh/) - React hooks for Ethereum
- [Viem](https://viem.sh/) - TypeScript interface for Ethereum
- [OnChainKit](https://onchainkit.xyz/) - Base/Coinbase onchain toolkit
- [Aave V3](https://aave.com/) - DeFi lending protocol integration for yield generation
- [TailwindCSS](https://tailwindcss.com/) - Utility-first CSS framework
- [daisyUI](https://daisyui.com/) - Tailwind CSS component library

## Team

- [Markkop](https://github.com/Markkop)
- [dutragustavo](https://github.com/dutragustavo)
- [hpereira1](https://github.com/hpereira1)
- [artur-simon](https://github.com/artur-simon)

## References

- [Base Batches 2025](https://www.basebatches.xyz/)
- [The effectiveness of financial incentives for health behaviour change: systematic review and meta-analysis](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0090347)
- [Prospect Theory: An Analysis of Decision Under Risk](https://www.jstor.org/stable/1914185)
- [The intention–behavior gap](https://psycnet.apa.org/record/2016-43197-003)

## Development Setup Instructions

- Clone the repository
- Run `pnpm install` to install the dependencies
- Run `pnpm start` to run the frontend
- Visit `http://localhost:3000` to see the app
- Run `pnpm fork` or `pnpm fork:fast` to run the local Base network (forked from Base mainnet)
- Run `pnpm run deploy` to deploy the contracts
- When running locally, use `targetNetworks: [chains.hardhat]` in `packages/nextjs/scaffold.config.ts`
- But when deploying to the testnet, use `targetNetworks: [chains.baseSepolia]`
