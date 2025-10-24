"use client";

import { useState } from "react";
import { formatEther, parseEther } from "viem";
import { useAccount } from "wagmi";
import { EtherInput } from "~~/components/scaffold-eth";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface CreateHabitModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const CreateHabitModal = ({ isOpen, onClose }: CreateHabitModalProps) => {
  const [habitName, setHabitName] = useState("Run in the morning");
  const [stakeAmount, setStakeAmount] = useState("0.001");
  const { address: connectedAddress } = useAccount();

  const { writeContractAsync: writeHabitChainAsync, isPending } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  // Read user balance - watch for blockchain changes
  const { data: userBalance } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserBalance",
    args: [connectedAddress],
    watch: true,
  });

  const handleCreateHabit = async () => {
    if (!habitName || !stakeAmount) {
      alert("Please fill in all fields");
      return;
    }

    try {
      const stakeAmountWei = parseEther(stakeAmount);

      await writeHabitChainAsync({
        functionName: "createHabit",
        args: [habitName, stakeAmountWei],
      });

      // Reset form and close modal
      setHabitName("");
      setStakeAmount("");
      onClose();
    } catch (error) {
      console.error("Error creating habit:", error);
    }
  };

  const handleClose = () => {
    setHabitName("");
    setStakeAmount("");
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box max-w-md">
        <h3 className="font-bold text-2xl mb-4">Create New Habit</h3>

        <div className="form-control mb-4">
          <label className="label">
            <span className="label-text">Habit Name</span>
          </label>
          <input
            type="text"
            placeholder="e.g., Morning Meditation"
            className="input input-bordered w-full"
            value={habitName}
            onChange={e => setHabitName(e.target.value)}
          />
        </div>

        <div className="form-control mb-4">
          <label className="label">
            <span className="label-text">Stake Amount (ETH)</span>
          </label>
          <EtherInput value={stakeAmount} onChange={value => setStakeAmount(value)} placeholder="0.1" />
          <label className="label">
            <span className="label-text-alt">Available: {userBalance ? formatEther(userBalance) : "0"} ETH</span>
            <span className="label-text-alt">Minimum: 0.001 ETH</span>
          </label>
        </div>

        <div className="alert alert-info mb-4">
          <div className="text-sm">
            <p className="font-semibold mb-1">How it works:</p>
            <ul className="list-disc list-inside space-y-1">
              <li>Your stake will be deposited into Aave to earn yield</li>
              <li>Check in daily to maintain your habit</li>
              <li>Complete successfully → get back stake + yield earned</li>
              <li>Fail to maintain → stake + yield goes to treasury</li>
            </ul>
          </div>
        </div>

        <div className="modal-action">
          <button className="btn btn-ghost" onClick={handleClose} disabled={isPending}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={handleCreateHabit}
            disabled={isPending || !habitName || !stakeAmount}
          >
            {isPending ? (
              <>
                <span className="loading loading-spinner"></span>
                Creating...
              </>
            ) : (
              "Create Habit"
            )}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={handleClose}></div>
    </div>
  );
};
