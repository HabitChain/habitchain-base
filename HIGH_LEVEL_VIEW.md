# HabitChain Project

## One-liner

- Stake on Yourself  
- Habits with real skin-in-the-game

## Call To Action

Most people give up on building habits because the results are slow and traditional rewards aren't motivating.  
What's missing is a system that combines financial commitment and real incentives to maintain discipline.

## Executive Summary

HabitChain is a blockchain dApp that turns **self‑discipline** into a **financial commitment**.

Users lock funds on their own habit, complete daily check‑ins, and—if successful—**reclaim their stake plus yield**.

If they fail, the **locked fund is slashed** to the protocol treasury (or, in groups, redistributed to successful peers).

The prototype proves one essential on‑chain action: **commit → check‑in → settle** via smart contract.

By adding real consequences and immediate feedback, HabitChain closes the **“motivation gap”**, aligning personal progress with tangible rewards.

### **Executive Summary (Non-Technical Version)**

HabitChain is a new kind of habit-building app that adds real consequences and real rewards to personal growth.

Instead of relying only on motivation, users make a small personal commitment to their goal — a financial pledge that keeps them accountable. If they stay consistent, they earn their commitment back with a bonus. If they give up, that value is redirected to the community.

The prototype demonstrates how this simple cycle — **commit, check in, and settle results daily** — turns discipline into something measurable and rewarding.

By combining behavioral psychology with transparent digital systems, HabitChain helps people stay consistent and close the “motivation gap” that makes most habits fail.


## Problem

Problem statement: People struggle to sustain new habits because motivation fades, **consequences are weak**, and rewards feel distant.

92% of Resolutions Fail: Resolutions fail because they are made on an **impulse of motivation** that is not sustained.

No Tangible Consequences: Traditional apps have no real impact. **Failing costs nothing; no skin in the game.**

Distant Rewards: Benefits of habits are long-term, but motivation is needed now.

**Current alternatives / workaround:** Traditional habit apps offer points/badges but no real stakes; accountability relies on self‑control and shallow rewards.

Why now: Web3 enables verifiable stakes, automated outcomes, and programmable group incentives at low cost on most blockchains.

## Target User

- Wellness seekers: they already tried a lot of habit apps and are looking for something unique  
- Students: they are looking for a way to stay motivated and focused on their studies  
- Crypto natives: they love using blockchain dApps, are used to earning and losing money, and could use a real utility dApp

## Prototype Scope

- User deposits tokens in the protocol  
- User creates two habits  
- User fund those habits with the tokens they deposited  
- User performs a daily check‑in for one habit, but doesn't for the other  
- By using a testing only "force settle" button they can either reclaim stake \+ yield (success) or have it slashed and distributed to the treasury.

What’s intentionally out of scope for the prototype:

- Settlement process on midnight 00:00 UTC  
- Group mode feature to redistribute failed stakes to connected peers.  
- Sponsor and campaigns systems  
- Mobile apps  
- Governance

## Terminology

- At Stake: The amount of money that a user has locked in the protocol for a habit, which can be lost or earned back.  
- Staked/staking: The earned back money which is now generated yield, usually with a external Staking smart contract integration  
- Rewards: The earned back money \+ yield  
- Settle: The process of triggering/resolving the end-of-the-day rewards and penalties, usually at midnight 00:00 UTC.

## Core/Features/Definitions

### Self-accountability

- Habits are self-attested: users do their own check in  
- The protocol intentionally performs no off-chain validation.  
- This is also the common behavior across Habit Tracking apps like Habitica.  
- The only harm the user can do is to themselves: self-sabotage.  
- Rewards and yield systems shall take this into account and limit extra rewards for fake checkins, spamming or loopholes.

### Slashing

- Slashing is the process of penalizing users who fail to complete their habits.  
- By default, the slashed amount is sent to the protocol treasury.  
- In group mode, the slashed amount is distributed to the group members that completed their habits.  
- Should we consider a "burn" mode so the slashed amount is actually burned/sent to the zero address?

### Rewards

By default, the user's reward is their own money. This is intended to trigger the "real reward" effect. Additional rewards can also be included, such as:

- Yield staking from external staking smart contracts  
- Protocol campaigns funded from the treasury  
- Sponsored campaigns funded from companies and organizations  
- Sliced value from other users who failed to complete their habits

### Liquidity

- We aim to integrate it with well-known protocols for generating revenue through liquidity staking. 
- Example of protocols: aave, compound 

### Group Mode

- Users can setup and invite/join users to private groups.  
- In this group mode, users that fail to complete their habits will have their stake sliced and distributed to the group members that completed their habits.  
- We might want to add a % of the slashed amount to go to the protocol treasury

### Settle

- Settle is the process of triggering/resolving the end-of-the-day rewards and penalties  
- At Stake balances are moved to Rewards balances on success  
- Or moved to the protocol treasury and/or group members on failure  
- Should happen at 00:00 UTC  
- Should we consider a "timezone" option so users can pick between 00:00 UTC / 06:00 UTC / 12:00 UTC / 18:00 UTC as "midgnight"?  
- Idea: to avoid having a external web2 dependency like a bot or a cron job, we could have a "Bounty" button where any user can click to trigger everyone's settlement if the time is past 00:00 UTC.  
- See the dedicated .md file about this Bounty Botton for more details.

## Roadmap/Next Steps

- [ ] Prototype it on testnets  
- [ ] Research staking protocols for yield rewards per user  
- [ ] Integrate real yield rewards  
- [ ] Group mode  
- [ ] Review settlement mechanism (midnight 00:00 UTC/bounty button)  
- [ ] Add sponsor/campaigns (funding) system  
- [ ] Plan/implement liquidity  
- [ ] Proof of habit keeping

## Competitors/Similar Apps

- [https://moonwalk.fit/](https://moonwalk.fit/) (Group accountability, has rewards, focuses on steps/smart watch integration, Solana)  
- [https://www.focustree.app/](https://www.focustree.app/) (Focus timer, rewards, Starknet)  
- [https://habitica.com/](https://habitica.com/) (Open-source web2 habit/todo gamification app)  
- [https://www.forfeit.app/](https://www.forfeit.app/) (Todo list with money accountability, has real-world verification, web2, mobile)

