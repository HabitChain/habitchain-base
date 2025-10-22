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
  const [refundAmount, setRefundAmount] = useState("");
  const [isRefundModalOpen, setIsRefundModalOpen] = useState(false);
  const [blockchainTimestamp, setBlockchainTimestamp] = useState<number>(0);

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

  // Fetch current blockchain timestamp
  useEffect(() => {
    const fetchBlockchainTimestamp = async () => {
      if (!publicClient) return;

      try {
        const block = await publicClient.getBlock({ blockTag: "latest" });
        setBlockchainTimestamp(Number(block.timestamp));
      } catch (error) {
        console.error("Error fetching blockchain timestamp:", error);
        // Fallback to local time if blockchain fetch fails
        setBlockchainTimestamp(Math.floor(Date.now() / 1000));
      }
    };

    fetchBlockchainTimestamp();

    // Update timestamp more frequently for testing (every 1 second if period <= 10 seconds, otherwise 30 seconds)
    const updateInterval = checkInPeriod && Number(checkInPeriod) <= 10 ? 1000 : 30000;
    const interval = setInterval(fetchBlockchainTimestamp, updateInterval);

    return () => clearInterval(interval);
  }, [publicClient, checkInPeriod]);

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
      setRefundAmount("");
    } catch (error) {
      console.error("Error refunding habit:", error);
      notification.error("Failed to refund habit");
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
  const now = blockchainTimestamp; // Use blockchain timestamp instead of local time
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
