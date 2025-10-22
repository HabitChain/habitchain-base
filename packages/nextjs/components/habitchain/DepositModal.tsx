"use client";

import { useState } from "react";
import { parseEther } from "viem";
import { useAccount, useBalance } from "wagmi";
import { EtherInput } from "~~/components/scaffold-eth";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface DepositModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const DepositModal = ({ isOpen, onClose }: DepositModalProps) => {
  const [amount, setAmount] = useState("0.1");
  const { address: connectedAddress } = useAccount();

  const { data: ethBalance } = useBalance({
    address: connectedAddress,
  });

  const { writeContractAsync: writeHabitChainAsync, isPending } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  const handleDeposit = async () => {
    if (!amount) {
      alert("Please enter an amount");
      return;
    }

    try {
      const depositAmountWei = parseEther(amount);

      await writeHabitChainAsync({
        functionName: "deposit",
        value: depositAmountWei,
      });

      // Reset form and close modal
      setAmount("");
      onClose();
    } catch (error) {
      console.error("Error depositing:", error);
    }
  };

  const handleClose = () => {
    setAmount("");
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box max-w-md">
        <h3 className="font-bold text-2xl mb-4">Deposit ETH</h3>

        <div className="form-control mb-4">
          <label className="label">
            <span className="label-text">Amount (ETH)</span>
          </label>
          <EtherInput value={amount} onChange={value => setAmount(value)} placeholder="1.0" />
          <label className="label">
            <span className="label-text-alt">
              Wallet Balance: {ethBalance ? parseFloat(parseEther(ethBalance.value.toString()).toString()) / 1e18 : 0}{" "}
              ETH
            </span>
          </label>
        </div>

        <div className="alert alert-info mb-4">
          <div className="text-sm">
            <p className="font-semibold mb-1">About deposits:</p>
            <ul className="list-disc list-inside space-y-1">
              <li>Deposit ETH to fund your habits</li>
              <li>Your balance can be withdrawn at any time</li>
              <li>Once staked on a habit, funds are locked until settlement</li>
            </ul>
          </div>
        </div>

        <div className="modal-action">
          <button className="btn btn-ghost" onClick={handleClose} disabled={isPending}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={handleDeposit} disabled={isPending || !amount}>
            {isPending ? (
              <>
                <span className="loading loading-spinner"></span>
                Depositing...
              </>
            ) : (
              "Deposit"
            )}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={handleClose}></div>
    </div>
  );
};
