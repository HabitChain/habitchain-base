"use client";

import { formatEther } from "viem";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { SettlementButton } from "./SettlementButton";

interface HabitCardProps {
  habitId: bigint;
}

export const HabitCard = ({ habitId }: HabitCardProps) => {
  const { data: habit } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getHabit",
    args: [habitId],
  });

  const { writeContractAsync: writeHabitChainAsync, isPending: isCheckingIn } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

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
  const now = Math.floor(Date.now() / 1000);
  const timeSinceLastCheckIn = lastCheckIn > 0 ? now - lastCheckIn : 0;
  const canCheckInAgain = lastCheckIn === 0 || timeSinceLastCheckIn >= 86400; // 24 hours

  // Format last check-in time
  const formatLastCheckIn = () => {
    if (lastCheckIn === 0) return "Never";
    const hours = Math.floor(timeSinceLastCheckIn / 3600);
    if (hours < 1) return "Less than 1 hour ago";
    if (hours < 24) return `${hours} hours ago`;
    const days = Math.floor(hours / 24);
    return `${days} day${days > 1 ? "s" : ""} ago`;
  };

  return (
    <div className={`card bg-base-100 shadow-xl border-2 ${isActive ? "border-primary" : "border-base-300"}`}>
      <div className="card-body">
        {/* Header */}
        <div className="flex items-start justify-between mb-2">
          <h3 className="card-title text-xl">{habit.name}</h3>
          <div className={`badge ${isActive ? "badge-primary" : isSettled ? "badge-ghost" : "badge-warning"}`}>
            {isActive ? "Active" : isSettled ? "Settled" : "Inactive"}
          </div>
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

        {/* Actions */}
        {isActive && (
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
                "Already checked in today"
              )}
            </button>

            <SettlementButton habitId={habitId} habitName={habit.name} />
          </div>
        )}

        {isSettled && (
          <div className="alert alert-success mt-2">
            <span className="text-sm">✓ Habit settled</span>
          </div>
        )}
      </div>
    </div>
  );
};

