"use client";

import type { NextPage } from "next";
import { formatEther } from "viem";
import { useScaffoldEventHistory, useScaffoldReadContract } from "~~/hooks/scaffold-eth";

const Treasury: NextPage = () => {
  // Read treasury balance
  const { data: treasuryBalance } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getTreasuryBalance",
  });

  // Get all treasury funding events
  const { data: treasuryEvents } = useScaffoldEventHistory({
    contractName: "HabitChain",
    eventName: "TreasuryFunded",
    fromBlock: 0n,
    watch: true,
  });

  // Get all settled habits
  const { data: settledEvents } = useScaffoldEventHistory({
    contractName: "HabitChain",
    eventName: "HabitSettled",
    fromBlock: 0n,
    watch: true,
  });

  console.log("Treasury Events:", treasuryEvents);
  console.log("Settled Events:", settledEvents);

  const successfulHabits = settledEvents?.filter(event => event.args.success) || [];
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const failedHabits = settledEvents?.filter(event => !event.args.success) || [];

  const totalYieldGenerated =
    settledEvents?.reduce((sum, event) => {
      return sum + BigInt(event.args.yieldEarned || 0);
    }, 0n) || 0n;

  const successRate =
    settledEvents && settledEvents.length > 0
      ? ((successfulHabits.length / settledEvents.length) * 100).toFixed(1)
      : "0";

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">Protocol Treasury</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title text-lg">Treasury Balance</h3>
            <p className="text-3xl font-bold">
              {treasuryBalance ? parseFloat(formatEther(treasuryBalance)).toFixed(4) : "0"} ETH
            </p>
            <p className="text-sm opacity-70">From slashed habits</p>
          </div>
        </div>

        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title text-lg">Total Yield Generated</h3>
            <p className="text-3xl font-bold">
              {totalYieldGenerated ? parseFloat(formatEther(totalYieldGenerated)).toFixed(4) : "0"} ETH
            </p>
            <p className="text-sm opacity-70">Across all habits</p>
          </div>
        </div>

        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title text-lg">Success Rate</h3>
            <p className="text-3xl font-bold">{successRate}%</p>
            <p className="text-sm opacity-70">
              {successfulHabits.length} successful / {settledEvents?.length || 0} total
            </p>
          </div>
        </div>
      </div>

      {/* Slashed Habits */}
      <div className="mb-8">
        <h2 className="text-2xl font-bold mb-4">Slashed Habits</h2>
        {treasuryEvents && treasuryEvents.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Habit ID</th>
                  <th>Amount Slashed</th>
                  <th>Block Number</th>
                  <th>Transaction</th>
                </tr>
              </thead>
              <tbody>
                {treasuryEvents.map((event, index) => (
                  <tr key={index}>
                    <td>#{event.args.habitId?.toString()}</td>
                    <td>{event.args.amount ? parseFloat(formatEther(event.args.amount)).toFixed(4) : "0"} ETH</td>
                    <td>{event.blockNumber?.toString()}</td>
                    <td>
                      <a
                        href={`https://basescan.org/tx/${event.transactionHash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="link link-primary"
                      >
                        View
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="card bg-base-200 shadow-xl">
            <div className="card-body items-center text-center">
              <p>No slashed habits yet</p>
            </div>
          </div>
        )}
      </div>

      {/* All Settled Habits */}
      <div>
        <h2 className="text-2xl font-bold mb-4">All Settled Habits</h2>
        {settledEvents && settledEvents.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Habit ID</th>
                  <th>User</th>
                  <th>Result</th>
                  <th>Total Amount</th>
                  <th>Yield Earned</th>
                  <th>Transaction</th>
                </tr>
              </thead>
              <tbody>
                {settledEvents.map((event, index) => (
                  <tr key={index}>
                    <td>#{event.args.habitId?.toString()}</td>
                    <td className="font-mono text-sm">
                      {event.args.user?.slice(0, 6)}...{event.args.user?.slice(-4)}
                    </td>
                    <td>
                      {event.args.success ? (
                        <span className="badge badge-success">Success</span>
                      ) : (
                        <span className="badge badge-error">Failed</span>
                      )}
                    </td>
                    <td>
                      {event.args.totalAmount ? parseFloat(formatEther(event.args.totalAmount)).toFixed(4) : "0"} ETH
                    </td>
                    <td>
                      {event.args.yieldEarned ? parseFloat(formatEther(event.args.yieldEarned)).toFixed(4) : "0"} ETH
                    </td>
                    <td>
                      <a
                        href={`https://basescan.org/tx/${event.transactionHash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="link link-primary"
                      >
                        View
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="card bg-base-200 shadow-xl">
            <div className="card-body items-center text-center">
              <p>No settled habits yet</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Treasury;
