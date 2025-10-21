# Happy Path Testing

Run the complete HabitChain happy path test scenario using Cursor's browser to verify the full user workflow from deposit to settlement.

## Instructions for AI

Follow the complete testing procedure outlined in `TESTING_HAPPY_PATH.md`:

1. **Environment Setup**: Ensure local blockchain (`yarn fork`), contract deployment (`yarn deploy`), and frontend (`yarn start`) are running
2. **Browser Testing**: Use Cursor's browser controls to navigate through the complete user flow:
   - Connect wallet and get test funds
   - Deposit 0.6 ETH
   - Create two habits ("Run in the morning" and "Go to the gym" with 0.2 ETH each)
   - Perform check-in on first habit only
   - Trigger global settlement
   - Verify results: one habit active, one slashed, treasury balance updated
3. **Verification**: Check all expected outcomes match the specification
4. **Report**: Document any issues or deviations from expected behavior

This command should be used to validate the complete HabitChain user experience in a browser environment.
