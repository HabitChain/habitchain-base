# HabitChain Happy Path Testing

## Test Scenario: Habit Check-in with One Slash

### Prerequisites
- Local blockchain running (`yarn chain`)
- Contract deployed (`yarn deploy`)
- Frontend running (`yarn start`)
- Browser wallet connected

### Test Steps

#### 1. Initial Setup
1. Open application at `http://localhost:3000`
2. Connect wallet
3. Get funds from faucet if balance < 0.6 ETH

#### 2. Deposit Funds
1. Navigate to deposit section
2. Enter amount: `0.6` ETH
3. Click "Deposit"
4. Confirm transaction
5. **Verify**: Available balance shows 0.6 ETH

#### 3. Create First Habit
1. Click "Create Habit" or navigate to habit creation
2. Enter habit name: `Run in the morning`
3. Enter stake amount: `0.2` ETH
4. Submit transaction
5. **Verify**: 
   - Habit appears in habit list
   - Available balance: 0.4 ETH
   - Habit status: Active/Funded

#### 4. Create Second Habit
1. Click "Create Habit"
2. Enter habit name: `Go to the gym`
3. Enter stake amount: `0.2` ETH
4. Submit transaction
5. **Verify**:
   - Both habits visible in list
   - Available balance: 0.2 ETH
   - Both habits status: Active/Funded

#### 5. Perform Check-in on First Habit
1. Locate "Run in the morning" habit
2. Click "Check-in" button
3. Confirm transaction
4. **Verify**: Check-in recorded for habit 1

#### 6. Skip Check-in on Second Habit
1. Do NOT click check-in for "Go to the gym"
2. **Verify**: No check-in recorded for habit 2

#### 7. Trigger Global Settlement
1. Locate "Global Settlement" or "Daily Settlement" button
2. Click button
3. Confirm transaction
4. Wait for transaction to complete

### Expected Results

#### Habit 1: "Run in the morning"
- **Status**: Active/Funded (back to initial state)
- **Stake**: 0.2 ETH (funds retained)
- **Check-in Status**: Reset (can check-in again tomorrow)
- **Yield**: Continue generating
- **Action Available**: Can check-in next period

#### Habit 2: "Go to the gym"
- **Status**: Slashed
- **Stake**: 0 ETH (slashed to treasury)
- **Check-in Status**: N/A (cannot check-in while slashed)
- **UI Elements**:
  - Shows "Slashed" indicator
  - Displays "Refund Habit" button
  - Check-in button disabled or hidden
- **Behavior**:
  - Cannot be slashed again while in slashed state
  - User can refund using available balance (0.2 ETH)

#### Treasury Balance
- **Expected**: 0.2 ETH (from slashed habit 2)
- **Verify**: Check treasury page or contract balance

#### User Available Balance
- **Expected**: 0.2 ETH (unchanged from before settlement)

### Verification Checklist

- [ ] Habit 1 shows active/funded status
- [ ] Habit 1 check-in counter reset
- [ ] Habit 1 stake amount: 0.2 ETH
- [ ] Habit 2 shows slashed status
- [ ] Habit 2 check-in disabled
- [ ] Habit 2 shows refund button
- [ ] Treasury balance: 0.2 ETH
- [ ] User available balance: 0.2 ETH
- [ ] Total user deposits: 0.6 ETH (0.2 available + 0.2 in habit 1 + 0.2 in treasury)

### Additional Tests to Consider

#### Test Refund Flow
1. Click "Refund Habit" on slashed habit 2
2. Enter refund amount: `0.2` ETH
3. Confirm transaction
4. **Expected**:
   - Habit 2 status back to Active/Funded
   - Available balance: 0 ETH
   - Habit 2 stake: 0.2 ETH

#### Test Next Day Scenario
1. Wait for next check-in period
2. Check-in on both habits
3. Trigger settlement
4. **Expected**: Both habits remain active, no slashing

### Common Issues

- **Settlement not triggering**: Check if enough time passed since last settlement
- **Check-in failing**: Verify habit is in active state, not slashed
- **Refund button missing**: Ensure habit is in slashed state
- **Treasury balance incorrect**: Check if previous tests left residual balance

### Contract State After Test

```
User Deposits: 0.6 ETH total
├── Available Balance: 0.2 ETH
├── Habit 1 Stake: 0.2 ETH (active, earning yield)
└── Treasury: 0.2 ETH (from slash)

Habit 1: Active, can check-in tomorrow
Habit 2: Slashed, needs refund to reactivate
```

