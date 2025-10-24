"use client";

import { useEffect, useState } from "react";
import { formatEther, parseEther } from "viem";
import { usePublicClient } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";

interface HabitCardProps {
  habitId: bigint;
}

export const HabitCard = ({ habitId }: HabitCardProps) => {
  const [refundAmount, setRefundAmount] = useState("0.001");
  const [isRefundModalOpen, setIsRefundModalOpen] = useState(false);
  const [localTimestamp, setLocalTimestamp] = useState<number>(0);
  const [isQuickRefunding, setIsQuickRefunding] = useState(false);

  const publicClient = usePublicClient();

  const { data: habit, refetch: refetchHabit } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getHabit",
    args: [habitId],
    watch: true,
  });

  const { data: checkInPeriod } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "checkInPeriod",
    watch: true,
  });

  const { data: cycleInfo } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getCycleInfo",
    watch: true,
  });

  const { data: habitCycleStatus, refetch: refetchCycleStatus } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getHabitCycleStatus",
    args: [habitId],
    watch: true,
  });

  const { data: cycleStartTime } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "cycleStartTime",
    watch: true,
  });

  const { writeContractAsync: writeHabitChainAsync, isPending: isCheckingIn } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  // Fetch current blockchain timestamp (reference point)
  useEffect(() => {
    const fetchBlockchainTimestamp = async () => {
      if (!publicClient) return;

      try {
        const block = await publicClient.getBlock({ blockTag: "latest" });
        const timestamp = Number(block.timestamp);
        setLocalTimestamp(timestamp);
      } catch (error) {
        console.error("Error fetching blockchain timestamp:", error);
        // Fallback to local time if blockchain fetch fails
        const timestamp = Math.floor(Date.now() / 1000);
        setLocalTimestamp(timestamp);
      }
    };

    fetchBlockchainTimestamp();

    // Update blockchain timestamp periodically for sync (every 5 seconds for short periods, 30 seconds for long)
    const updateInterval = checkInPeriod && Number(checkInPeriod) <= 60 ? 5000 : 30000;
    const interval = setInterval(fetchBlockchainTimestamp, updateInterval);

    return () => clearInterval(interval);
  }, [publicClient, checkInPeriod]);

  // Local countdown timer (updates every second for smooth countdown)
  useEffect(() => {
    const timer = setInterval(() => {
      setLocalTimestamp(prev => prev + 1);
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  const handleCheckIn = async () => {
    try {
      await writeHabitChainAsync({
        functionName: "checkIn",
        args: [habitId],
      });
      // Force refetch to get latest blockchain state
      await Promise.all([refetchHabit(), refetchCycleStatus()]);
      notification.success("Check-in successful!");
    } catch (error) {
      console.error("Error checking in:", error);
      notification.error("Check-in failed");
    }
  };

  const handleRefund = async () => {
    if (!refundAmount || parseFloat(refundAmount) <= 0) {
      notification.error("Please enter a valid refund amount");
      return;
    }

    try {
      await writeHabitChainAsync({
        functionName: "refundHabit",
        args: [habitId, parseEther(refundAmount)],
      });
      // Force refetch to get latest blockchain state
      await Promise.all([refetchHabit(), refetchCycleStatus()]);
      notification.success("Habit refunded successfully!");
      setIsRefundModalOpen(false);
      setRefundAmount("0.001");
    } catch (error) {
      console.error("Error refunding habit:", error);
      notification.error("Failed to refund habit");
    }
  };

  const handleQuickRefund = async () => {
    try {
      setIsQuickRefunding(true);
      const defaultRefundAmount = parseEther("0.001");
      await writeHabitChainAsync({
        functionName: "refundHabit",
        args: [habitId, defaultRefundAmount],
      });
      // Force refetch to get latest blockchain state
      await Promise.all([refetchHabit(), refetchCycleStatus()]);
      notification.success("Quick refund of 0.001 ETH completed!");
    } catch (error) {
      console.error("Error refunding habit:", error);
      notification.error("Quick refund failed");
    } finally {
      setIsQuickRefunding(false);
    }
  };

  if (!habit) {
    return (
      <div className="card bg-base-100 shadow-xl">
        <div className="card-body">
          <div className="animate-pulse">Loading...</div>
        </div>
      </div>
    );
  }

  const isActive = habit.isActive;
  const isSettled = habit.isSettled;
  const stakeAmount = formatEther(habit.stakeAmount);
  const checkInCount = habit.checkInCount.toString();
  const lastCheckIn = Number(habit.lastCheckIn);
  const now = localTimestamp; // Use local countdown timestamp for smooth updates

  // Cycle-based logic
  const currentCycle = cycleInfo ? Number(cycleInfo[0]) : 0;
  const cycleEndTime = cycleInfo ? Number(cycleInfo[2]) : 0;
  const lastCheckInCycle = habitCycleStatus ? Number(habitCycleStatus[0]) : 0;
  const checkedInThisCycle = habitCycleStatus ? habitCycleStatus[1] : false;

  // Detect slashed status: isActive but stakeAmount is 0
  const isSlashed = isActive && habit.stakeAmount === 0n;

  // Check if habit needs settlement before allowing check-in
  const needsSettlement = () => {
    if (!habit || !cycleStartTime || !checkInPeriod) return false;
    if (isSlashed) return false; // Slashed habits don't need settlement check

    // Calculate creation cycle
    const creationCycle = Number((habit.createdAt - cycleStartTime) / checkInPeriod);

    // If we're still in the creation cycle, no settlement needed
    if (currentCycle <= creationCycle) return false;

    const lastSettledCycle = habit.lastSettledCycle;

    // Check if previous cycles need to be settled
    // Special case: type(uint256).max is sentinel value meaning never settled
    const MAX_UINT256 = 2n ** 256n - 1n;
    if (lastSettledCycle === MAX_UINT256) {
      return true; // Never settled, needs settlement
    }

    // Check if we've settled all cycles up to current - 1
    if (lastSettledCycle < BigInt(currentCycle - 1)) {
      return true; // Previous cycle not settled yet
    }

    return false;
  };

  const isPendingSettlement = needsSettlement();
  const canCheckInAgain = !checkedInThisCycle && !isPendingSettlement;

  // Format last check-in cycle
  const formatLastCheckIn = () => {
    if (lastCheckIn === 0) return "Never";
    if (lastCheckInCycle === 0) return "Never";
    return `Cycle ${lastCheckInCycle}`;
  };

  // Calculate time remaining in current cycle
  const getTimeRemainingInCycle = () => {
    if (!cycleEndTime) return 0;
    const timeRemaining = cycleEndTime - now;
    return Math.max(0, timeRemaining);
  };

  const timeRemainingInCycle = getTimeRemainingInCycle();

  // Format duration in a human-readable way
  const formatDuration = (seconds: number) => {
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    if (seconds < 86400) {
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      return `${hours}h ${minutes}m`;
    }
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    return `${days}d ${hours}h`;
  };

  // Determine card status
  const getStatusBadge = () => {
    if (isSlashed) return <div className="badge badge-error">Slashed</div>;
    if (isSettled) return <div className="badge badge-ghost">Settled</div>;
    if (isActive) return <div className="badge badge-primary">Active</div>;
    return <div className="badge badge-warning">Inactive</div>;
  };

  const getCardBorderClass = () => {
    if (isSlashed) return "border-error";
    if (isActive) return "border-primary";
    return "border-base-300";
  };

  return (
    <div className={`card bg-base-100 shadow-xl border-2 ${getCardBorderClass()}`}>
      <div className="card-body">
        {/* Header */}
        <div className="flex items-start justify-between mb-2">
          <h3 className="card-title text-xl">{habit.name}</h3>
          {getStatusBadge()}
        </div>

        {/* Stats */}
        <div className="space-y-2 mb-4">
          <div className="flex justify-between items-center">
            <span className="text-sm opacity-70">Stake:</span>
            <span className="font-semibold">{parseFloat(stakeAmount).toFixed(4)} ETH</span>
          </div>

          <div className="flex justify-between items-center">
            <span className="text-sm opacity-70">Check-ins:</span>
            <span className="font-semibold">{checkInCount}</span>
          </div>

          <div className="flex justify-between items-center">
            <span className="text-sm opacity-70">Last check-in:</span>
            <span className="text-sm">{formatLastCheckIn()}</span>
          </div>

          {/* Cycle information */}
          {isActive && !isSlashed && (
            <>
              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Current cycle:</span>
                <span className="text-sm font-semibold">Cycle {currentCycle}</span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Checked in this cycle:</span>
                <span className={`text-sm font-semibold ${checkedInThisCycle ? "text-success" : "text-warning"}`}>
                  {checkedInThisCycle ? "✓ Yes" : "✗ No"}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Cycle ends in:</span>
                <span className="text-sm font-semibold text-info">{formatDuration(timeRemainingInCycle)}</span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Cycle deadline:</span>
                <span className="text-xs opacity-80">
                  {cycleEndTime ? new Date(cycleEndTime * 1000).toLocaleString() : "Loading..."}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Last settled cycle:</span>
                <span className="text-xs opacity-80">
                  {habit.lastSettledCycle === 2n ** 256n - 1n ? "Never" : `Cycle ${habit.lastSettledCycle.toString()}`}
                </span>
              </div>
            </>
          )}
        </div>

        {/* Slashed Alert */}
        {isSlashed && (
          <div className="alert alert-error mb-4">
            <span className="text-sm">⚠️ This habit was slashed. Refund to reactivate.</span>
          </div>
        )}

        {/* Pending Settlement Alert */}
        {isActive && !isSlashed && isPendingSettlement && (
          <div className="alert alert-warning mb-4">
            <span className="text-sm">⏳ Pending settlement - please click "Natural Settle" first</span>
          </div>
        )}

        {/* Actions for Active Funded Habits */}
        {isActive && !isSlashed && (
          <div className="card-actions flex-col gap-2">
            <button
              className="btn btn-primary btn-block"
              onClick={handleCheckIn}
              disabled={!canCheckInAgain || isCheckingIn}
            >
              {isCheckingIn ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Checking in...
                </>
              ) : isPendingSettlement ? (
                "⏳ Needs settlement first"
              ) : canCheckInAgain ? (
                "✓ Check In"
              ) : (
                "Already checked in this cycle"
              )}
            </button>
          </div>
        )}

        {/* Actions for Slashed Habits */}
        {isSlashed && (
          <div className="card-actions flex-col gap-2">
            <button className="btn btn-warning btn-block" onClick={() => setIsRefundModalOpen(true)}>
              💰 Refund Habit
            </button>
            <button
              className="btn btn-warning btn-outline btn-block"
              onClick={handleQuickRefund}
              disabled={isQuickRefunding}
              title="Quick refund 0.001 ETH"
            >
              {isQuickRefunding ? <span className="loading loading-spinner loading-sm"></span> : "Quick Refund"}
            </button>
          </div>
        )}

        {/* Settled Status */}
        {isSettled && (
          <div className="alert alert-success mt-2">
            <span className="text-sm">✓ Habit settled</span>
          </div>
        )}
      </div>

      {/* Refund Modal */}
      {isRefundModalOpen && (
        <dialog className="modal modal-open">
          <div className="modal-box">
            <h3 className="font-bold text-lg mb-4">Refund Habit: {habit.name}</h3>
            <p className="mb-4 text-sm opacity-70">
              This habit was slashed. Enter an amount to restake and reactivate it.
            </p>

            <div className="form-control">
              <label className="label">
                <span className="label-text">Refund Amount (ETH)</span>
              </label>
              <input
                type="number"
                placeholder="0.1"
                className="input input-bordered"
                value={refundAmount}
                onChange={e => setRefundAmount(e.target.value)}
                step="0.001"
                min="0.001"
              />
            </div>

            <div className="modal-action">
              <button className="btn" onClick={() => setIsRefundModalOpen(false)}>
                Cancel
              </button>
              <button className="btn btn-warning" onClick={handleRefund}>
                Refund & Reactivate
              </button>
            </div>
          </div>
          <form method="dialog" className="modal-backdrop" onClick={() => setIsRefundModalOpen(false)}>
            <button>close</button>
          </form>
        </dialog>
      )}
    </div>
  );
};
