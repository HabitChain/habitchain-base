"use client";

import { useState } from "react";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { Address } from "~~/components/scaffold-eth";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { CreateHabitModal } from "./CreateHabitModal";
import { DepositModal } from "./DepositModal";
import { WithdrawModal } from "./WithdrawModal";
import { HabitCard } from "./HabitCard";

export const Dashboard = () => {
  const { address: connectedAddress } = useAccount();
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isDepositModalOpen, setIsDepositModalOpen] = useState(false);
  const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState(false);

  // Read user balance
  const { data: userBalance } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserBalance",
    args: [connectedAddress],
  });

  // Read user habits
  const { data: userHabitIds } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserHabits",
    args: [connectedAddress],
  });

  // Read active habits count
  const { data: activeHabitsCount } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserActiveHabitsCount",
    args: [connectedAddress],
  });

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

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
              <h3 className="card-title text-lg">Available Balance</h3>
              <p className="text-3xl font-bold">{userBalance ? `${parseFloat(formatEther(userBalance)).toFixed(4)} ETH` : "0 ETH"}</p>
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
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-4 mb-8">
        <button className="btn btn-success" onClick={() => setIsDepositModalOpen(true)}>
          💰 Deposit ETH
        </button>
        <button className="btn btn-warning" onClick={() => setIsWithdrawModalOpen(true)}>
          💸 Withdraw ETH
        </button>
        <button className="btn btn-primary" onClick={() => setIsCreateModalOpen(true)}>
          ➕ Create New Habit
        </button>
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

