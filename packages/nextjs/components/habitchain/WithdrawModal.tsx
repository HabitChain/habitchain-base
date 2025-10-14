"use client";

import { useState } from "react";
import { parseEther, formatEther } from "viem";
import { useAccount } from "wagmi";
import { EtherInput } from "~~/components/scaffold-eth";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const WithdrawModal = ({ isOpen, onClose }: WithdrawModalProps) => {
  const [amount, setAmount] = useState("");
  const { address: connectedAddress } = useAccount();

  const { data: userBalance } = useScaffoldReadContract({
    contractName: "HabitChain",
    functionName: "getUserBalance",
    args: [connectedAddress],
  });

  const { writeContractAsync: writeHabitChainAsync, isPending } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  const handleWithdraw = async () => {
    if (!amount) {
      alert("Please enter an amount");
      return;
    }

    try {
      const withdrawAmountWei = parseEther(amount);

      await writeHabitChainAsync({
        functionName: "withdraw",
        args: [withdrawAmountWei],
      });

      // Reset form and close modal
      setAmount("");
      onClose();
    } catch (error) {
      console.error("Error withdrawing:", error);
    }
  };

  const handleClose = () => {
    setAmount("");
    onClose();
  };

  const handleMaxWithdraw = () => {
    if (userBalance) {
      setAmount(formatEther(userBalance));
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box max-w-md">
        <h3 className="font-bold text-2xl mb-4">Withdraw ETH</h3>

        <div className="form-control mb-4">
          <label className="label">
            <span className="label-text">Amount (ETH)</span>
          </label>
          <EtherInput value={amount} onChange={value => setAmount(value)} placeholder="1.0" />
          <label className="label">
            <span className="label-text-alt">
              Available Balance: {userBalance ? parseFloat(formatEther(userBalance)).toFixed(4) : "0"} ETH
            </span>
            <button className="btn btn-xs btn-ghost" onClick={handleMaxWithdraw}>
              MAX
            </button>
          </label>
        </div>

        <div className="alert alert-warning mb-4">
          <div className="text-sm">
            <p className="font-semibold mb-1">Note:</p>
            <ul className="list-disc list-inside space-y-1">
              <li>You can only withdraw your available balance</li>
              <li>Funds staked on active habits cannot be withdrawn</li>
              <li>ETH will be sent to your connected wallet</li>
            </ul>
          </div>
        </div>

        <div className="modal-action">
          <button className="btn btn-ghost" onClick={handleClose} disabled={isPending}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={handleWithdraw} disabled={isPending || !amount}>
            {isPending ? (
              <>
                <span className="loading loading-spinner"></span>
                Withdrawing...
              </>
            ) : (
              "Withdraw"
            )}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={handleClose}></div>
    </div>
  );
};

