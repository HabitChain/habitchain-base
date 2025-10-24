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

  const { data: habit } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getHabit",
    args: [habitId],
  });

  const { data: checkInPeriod } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "checkInPeriod",
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
    } catch (error) {
      console.error("Error checking in:", error);
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
  const timeSinceLastCheckIn = lastCheckIn > 0 ? now - lastCheckIn : 0;
  const currentCheckInPeriod = checkInPeriod ? Number(checkInPeriod) : 86400; // Default to 24h if not loaded
  const canCheckInAgain = lastCheckIn === 0 || timeSinceLastCheckIn >= currentCheckInPeriod;

  // Detect slashed status: isActive but stakeAmount is 0
  const isSlashed = isActive && habit.stakeAmount === 0n;

  // Format last check-in time
  const formatLastCheckIn = () => {
    if (lastCheckIn === 0) return "Never";
    const periodHours = Math.floor(currentCheckInPeriod / 3600);
    const hours = Math.floor(timeSinceLastCheckIn / 3600);
    if (hours < 1) return "Less than 1 hour ago";
    if (periodHours <= 24) return `${hours} hours ago`;
    const days = Math.floor(hours / 24);
    return `${days} day${days > 1 ? "s" : ""} ago`;
  };

  // Calculate time until next check-in is available
  const getTimeUntilNextCheckIn = () => {
    if (lastCheckIn === 0) return "Now";
    const timeUntilNextCheckIn = currentCheckInPeriod - timeSinceLastCheckIn;
    if (timeUntilNextCheckIn <= 0) return "Now";
    return formatDuration(timeUntilNextCheckIn);
  };

  // Calculate check-in deadline (when habit gets slashed if not checked in)
  const getCheckInDeadline = () => {
    let deadlineTimestamp: number;

    if (lastCheckIn === 0 && Number(habit.lastSettled) > 0) {
      // Refunded habit - deadline is from lastSettled
      deadlineTimestamp = Number(habit.lastSettled) + currentCheckInPeriod;
    } else if (lastCheckIn === 0) {
      // Brand new habit - deadline is from creation
      deadlineTimestamp = Number(habit.createdAt) + currentCheckInPeriod;
    } else {
      // Normal habit - deadline is from last check-in + period
      deadlineTimestamp = lastCheckIn + currentCheckInPeriod;
    }

    const timeRemaining = deadlineTimestamp - now;

    return {
      timestamp: deadlineTimestamp,
      timeRemaining: Math.max(0, timeRemaining),
      isExpired: timeRemaining <= 0,
    };
  };

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

  const deadline = getCheckInDeadline();

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

          {/* Next check-in available */}
          {isActive && !isSlashed && (
            <div className="flex justify-between items-center">
              <span className="text-sm opacity-70">Next check-in in:</span>
              <span className={`text-sm font-semibold ${canCheckInAgain ? "text-success" : "text-warning"}`}>
                {getTimeUntilNextCheckIn()}
              </span>
            </div>
          )}

          {/* Check-in deadline */}
          {isActive && !isSlashed && (
            <>
              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Time to deadline:</span>
                <span className={`text-sm font-semibold ${deadline.isExpired ? "text-error" : "text-info"}`}>
                  {deadline.isExpired ? "EXPIRED" : formatDuration(deadline.timeRemaining)}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Check-in valid until:</span>
                <span className="text-xs opacity-80">{new Date(deadline.timestamp * 1000).toLocaleString()}</span>
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
              ) : canCheckInAgain ? (
                "✓ Check In"
              ) : (
                "Already checked in this period"
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
