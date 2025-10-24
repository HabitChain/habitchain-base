"use client";

import { useEffect, useState } from "react";
import { CreateHabitModal } from "./CreateHabitModal";
import { DepositModal } from "./DepositModal";
import { HabitCard } from "./HabitCard";
import { WithdrawModal } from "./WithdrawModal";
import { formatEther, parseEther } from "viem";
import { useAccount } from "wagmi";
import { usePublicClient } from "wagmi";
import { Address } from "~~/components/scaffold-eth";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";

export const Dashboard = () => {
  const { address: connectedAddress } = useAccount();
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isDepositModalOpen, setIsDepositModalOpen] = useState(false);
  const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState(false);
  const [isSettling, setIsSettling] = useState(false);
  const [isUpdatingPeriod, setIsUpdatingPeriod] = useState(false);
  const [blockchainTimestamp, setBlockchainTimestamp] = useState<number>(0);
  const [isMining, setIsMining] = useState(false);
  const [isQuickDepositing, setIsQuickDepositing] = useState(false);
  const [isQuickCreating, setIsQuickCreating] = useState(false);

  const publicClient = usePublicClient();

  // Write contract hook
  const { writeContractAsync: writeHabitChainAsync } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  // Read user balance
  const { data: userBalance, refetch: refetchUserBalance } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserBalance",
    args: [connectedAddress],
    watch: true,
  });

  // Read check-in period
  const { data: checkInPeriod } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "checkInPeriod",
    watch: true,
  });

  // Read cycle info
  const { data: cycleInfo, refetch: refetchCycleInfo } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getCycleInfo",
    watch: true,
  });

  // Fetch blockchain timestamp for debugging
  useEffect(() => {
    const fetchBlockchainTimestamp = async () => {
      if (!publicClient) return;

      try {
        const block = await publicClient.getBlock({ blockTag: "latest" });
        setBlockchainTimestamp(Number(block.timestamp));
      } catch (error) {
        console.error("Error fetching blockchain timestamp:", error);
        setBlockchainTimestamp(Math.floor(Date.now() / 1000));
      }
    };

    fetchBlockchainTimestamp();

    // Update timestamp frequently for debugging
    const interval = setInterval(fetchBlockchainTimestamp, 1000);

    return () => clearInterval(interval);
  }, [publicClient]);

  // Read user habits
  const { data: userHabitIds, refetch: refetchUserHabits } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserHabits",
    args: [connectedAddress],
    watch: true,
  });

  // Read active habits count (excludes slashed habits)
  const { data: activeHabitsCount, refetch: refetchActiveHabitsCount } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserActiveHabitsCount",
    args: [connectedAddress],
    watch: true,
  });

  const handleQuickDeposit = async () => {
    if (!connectedAddress) {
      notification.error("Please connect your wallet");
      return;
    }

    try {
      setIsQuickDepositing(true);
      const defaultAmount = parseEther("0.01");
      await writeHabitChainAsync({
        functionName: "deposit",
        value: defaultAmount,
      });
      // Force refetch to get latest blockchain state
      await refetchUserBalance();
      notification.success("Quick deposit of 0.01 ETH completed!");
    } catch (error) {
      console.error("Error depositing:", error);
      notification.error("Quick deposit failed");
    } finally {
      setIsQuickDepositing(false);
    }
  };

  const handleQuickCreateHabit = async () => {
    if (!connectedAddress) {
      notification.error("Please connect your wallet");
      return;
    }

    try {
      setIsQuickCreating(true);
      const randomNum = Math.floor(Math.random() * 1000);
      const habitName = `Run in the morning ${randomNum}`;
      const defaultStake = parseEther("0.001");

      await writeHabitChainAsync({
        functionName: "createHabit",
        args: [habitName, defaultStake],
      });
      // Force refetch to get latest blockchain state
      await Promise.all([refetchUserBalance(), refetchUserHabits(), refetchActiveHabitsCount()]);
      notification.success(`Quick habit "${habitName}" created!`);
    } catch (error) {
      console.error("Error creating habit:", error);
      notification.error("Quick create habit failed");
    } finally {
      setIsQuickCreating(false);
    }
  };

  const handleNaturalSettle = async () => {
    if (!connectedAddress) {
      notification.error("Please connect your wallet");
      return;
    }

    try {
      setIsSettling(true);
      await writeHabitChainAsync({
        functionName: "naturalSettle",
      });
      // Force refetch ALL data to get latest blockchain state
      // This is critical as settlement affects habits, balances, and cycle info
      await Promise.all([refetchUserBalance(), refetchUserHabits(), refetchActiveHabitsCount(), refetchCycleInfo()]);
      notification.success("Natural settlement completed successfully! UI refreshed with blockchain state.");
    } catch (error) {
      console.error("Error settling habits:", error);
      notification.error("Failed to settle habits. No eligible habits or transaction failed.");
    } finally {
      setIsSettling(false);
    }
  };

  const handleSetCheckInPeriod = async (period: bigint) => {
    if (!connectedAddress) {
      notification.error("Please connect your wallet");
      return;
    }

    try {
      setIsUpdatingPeriod(true);
      await writeHabitChainAsync({
        functionName: "setCheckInPeriod",
        args: [period],
      });
      const periodText = period === 5n ? "5 seconds" : period === 30n ? "30 seconds" : "24 hours";
      notification.success(`Check-in period updated to ${periodText}!`);
    } catch (error) {
      console.error("Error updating check-in period:", error);
      notification.error("Failed to update check-in period");
    } finally {
      setIsUpdatingPeriod(false);
    }
  };

  const handleMineBlock = async () => {
    if (!publicClient) return;

    try {
      setIsMining(true);
      // Send a no-op transaction to mine a block and advance timestamp
      await (publicClient as any).request({
        method: "evm_mine",
        params: [],
      });
      notification.success("Block mined - timestamp updated!");
      // Force refresh timestamp
      const block = await publicClient.getBlock({ blockTag: "latest" });
      setBlockchainTimestamp(Number(block.timestamp));
    } catch (error) {
      console.error("Error mining block:", error);
      notification.error("Failed to mine block");
    } finally {
      setIsMining(false);
    }
  };

  const handleAdvanceTime = async (seconds: number) => {
    if (!publicClient) return;

    try {
      setIsMining(true);
      // Increase time by specified seconds
      await (publicClient as any).request({
        method: "evm_increaseTime",
        params: [seconds],
      });
      // Mine a block to apply the time change
      await (publicClient as any).request({
        method: "evm_mine",
        params: [],
      });
      notification.success(`Time advanced by ${seconds} seconds!`);
      // Force refresh timestamp
      const block = await publicClient.getBlock({ blockTag: "latest" });
      setBlockchainTimestamp(Number(block.timestamp));
    } catch (error) {
      console.error("Error advancing time:", error);
      notification.error("Failed to advance time");
    } finally {
      setIsMining(false);
    }
  };

  if (!connectedAddress) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center">
          <h2 className="text-3xl font-bold mb-4">Welcome to HabitChain</h2>
          <p className="text-xl mb-8">Connect your wallet to start building habits with real skin in the game</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {/* User Stats */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-4xl font-bold mb-2">HabitChain Dashboard</h1>
            <div className="flex items-center gap-2">
              <span className="text-sm">Connected:</span>
              <Address address={connectedAddress} />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h3 className="card-title text-lg">Available Balance</h3>
              <p className="text-3xl font-bold">
                {userBalance ? `${parseFloat(formatEther(userBalance)).toFixed(4)} ETH` : "0 ETH"}
              </p>
            </div>
          </div>

          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h3 className="card-title text-lg">Active Habits</h3>
              <p className="text-3xl font-bold">{activeHabitsCount?.toString() || "0"}</p>
            </div>
          </div>

          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h3 className="card-title text-lg">Total Habits</h3>
              <p className="text-3xl font-bold">{userHabitIds?.length || "0"}</p>
            </div>
          </div>

          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h3 className="card-title text-sm">Global Cycle Info</h3>

              {/* Current Cycle Display */}
              <div className="mb-2">
                <div className="text-xs opacity-70">Current Cycle:</div>
                <div className="text-2xl font-bold text-primary">
                  {cycleInfo ? `Cycle ${cycleInfo[0].toString()}` : "Loading..."}
                </div>
              </div>

              {/* Cycle End Time */}
              {cycleInfo && (
                <div className="mb-2">
                  <div className="text-xs opacity-70">Cycle ends:</div>
                  <div className="text-xs font-semibold">
                    {new Date(Number(cycleInfo[2]) * 1000).toLocaleTimeString()}
                  </div>
                  <div className="text-xs opacity-60">
                    {Math.max(0, Number(cycleInfo[2]) - blockchainTimestamp)}s remaining
                  </div>
                </div>
              )}

              {/* Check-in Period Controls */}
              <div className="divider my-1"></div>
              <div className="text-xs opacity-70 mb-1">Period:</div>
              <div className="flex gap-1">
                <button
                  className={`btn btn-xs ${checkInPeriod === 5n ? "btn-success" : "btn-outline"}`}
                  onClick={() => handleSetCheckInPeriod(5n)}
                  disabled={isUpdatingPeriod || checkInPeriod === 5n}
                >
                  {isUpdatingPeriod && checkInPeriod === 5n ? (
                    <span className="loading loading-spinner loading-xs"></span>
                  ) : (
                    "5s"
                  )}
                </button>
                <button
                  className={`btn btn-xs ${checkInPeriod === 30n ? "btn-success" : "btn-outline"}`}
                  onClick={() => handleSetCheckInPeriod(30n)}
                  disabled={isUpdatingPeriod || checkInPeriod === 30n}
                >
                  {isUpdatingPeriod && checkInPeriod === 30n ? (
                    <span className="loading loading-spinner loading-xs"></span>
                  ) : (
                    "30s"
                  )}
                </button>
                <button
                  className={`btn btn-xs ${checkInPeriod === 60n ? "btn-success" : "btn-outline"}`}
                  onClick={() => handleSetCheckInPeriod(60n)}
                  disabled={isUpdatingPeriod || checkInPeriod === 60n}
                >
                  {isUpdatingPeriod && checkInPeriod === 60n ? (
                    <span className="loading loading-spinner loading-xs"></span>
                  ) : (
                    "1m"
                  )}
                </button>
                <button
                  className={`btn btn-xs ${checkInPeriod === 86400n ? "btn-success" : "btn-outline"}`}
                  onClick={() => handleSetCheckInPeriod(86400n)}
                  disabled={isUpdatingPeriod || checkInPeriod === 86400n}
                >
                  {isUpdatingPeriod && checkInPeriod === 86400n ? (
                    <span className="loading loading-spinner loading-xs"></span>
                  ) : (
                    "24h"
                  )}
                </button>
              </div>

              {/* Time Controls */}
              <div className="divider my-1"></div>
              <div className="text-xs opacity-70">🕒 {new Date(blockchainTimestamp * 1000).toLocaleString()}</div>
              <div className="flex gap-1 mt-1 flex-wrap">
                <button className="btn btn-xs btn-outline" onClick={handleMineBlock} disabled={isMining}>
                  {isMining ? <span className="loading loading-spinner loading-xs"></span> : "⛏️"}
                </button>
                <button className="btn btn-xs btn-outline" onClick={() => handleAdvanceTime(5)} disabled={isMining}>
                  {isMining ? <span className="loading loading-spinner loading-xs"></span> : "+5s"}
                </button>
                <button className="btn btn-xs btn-outline" onClick={() => handleAdvanceTime(30)} disabled={isMining}>
                  {isMining ? <span className="loading loading-spinner loading-xs"></span> : "+30s"}
                </button>
                <button className="btn btn-xs btn-outline" onClick={() => handleAdvanceTime(60)} disabled={isMining}>
                  {isMining ? <span className="loading loading-spinner loading-xs"></span> : "+1m"}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3 mb-8 flex-wrap items-center">
        <button className="btn btn-success" onClick={() => setIsDepositModalOpen(true)}>
          💰 Deposit ETH
        </button>
        <button
          className="btn btn-success btn-outline"
          onClick={handleQuickDeposit}
          disabled={isQuickDepositing}
          title="Quick deposit 0.01 ETH"
        >
          {isQuickDepositing ? <span className="loading loading-spinner loading-sm"></span> : "Quick deposit"}
        </button>

        <button className="btn btn-warning" onClick={() => setIsWithdrawModalOpen(true)}>
          💸 Withdraw ETH
        </button>

        <button className="btn btn-primary" onClick={() => setIsCreateModalOpen(true)}>
          ➕ Create New Habit
        </button>
        <button
          className="btn btn-primary btn-outline"
          onClick={handleQuickCreateHabit}
          disabled={isQuickCreating}
          title="Quick create habit with default values"
        >
          {isQuickCreating ? <span className="loading loading-spinner loading-sm"></span> : "Quick new habit"}
        </button>

        <button className="btn btn-error" onClick={handleNaturalSettle} disabled={isSettling}>
          {isSettling ? (
            <>
              <span className="loading loading-spinner loading-sm"></span>
              Settling...
            </>
          ) : (
            "⚖️ Natural Settle"
          )}
        </button>
      </div>

      {/* Info Text */}
      <div className="mb-6">
        <p className="text-xs opacity-60 max-w-2xl">
          💡 <span className="font-semibold">All habits share synchronized cycles</span> (
          {checkInPeriod ? `${Number(checkInPeriod)}s` : "loading..."} each). You can check in once per cycle. Natural
          Settle evaluates all habits at cycle boundaries - those checked in during the previous cycle succeed, others
          are slashed. Quick buttons use default values for instant actions.
        </p>
      </div>

      {/* Habits Grid */}
      <div>
        <h2 className="text-2xl font-bold mb-4">Your Habits</h2>
        {userHabitIds && userHabitIds.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {userHabitIds.map((habitId: bigint) => (
              <HabitCard key={habitId.toString()} habitId={habitId} />
            ))}
          </div>
        ) : (
          <div className="card bg-base-200 shadow-xl">
            <div className="card-body items-center text-center">
              <h3 className="text-xl font-semibold mb-2">No habits yet</h3>
              <p className="mb-4">Create your first habit to start building discipline with real stakes!</p>
              <button className="btn btn-primary" onClick={() => setIsCreateModalOpen(true)}>
                Create Your First Habit
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Modals */}
      <CreateHabitModal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} />
      <DepositModal isOpen={isDepositModalOpen} onClose={() => setIsDepositModalOpen(false)} />
      <WithdrawModal isOpen={isWithdrawModalOpen} onClose={() => setIsWithdrawModalOpen(false)} />
    </div>
  );
};
