"use client";

import { useState } from "react";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface SettlementButtonProps {
  habitId: bigint;
  habitName: string;
}

export const SettlementButton = ({ habitId, habitName }: SettlementButtonProps) => {
  const [showConfirm, setShowConfirm] = useState(false);

  const { writeContractAsync: writeHabitChainAsync, isPending } = useScaffoldWriteContract({
    contractName: "HabitChain",
  });

  const handleSettle = async (success: boolean) => {
    try {
      await writeHabitChainAsync({
        functionName: "forceSettle",
        args: [habitId, success],
      });

      setShowConfirm(false);
    } catch (error) {
      console.error("Error settling habit:", error);
    }
  };

  if (!showConfirm) {
    return (
      <button className="btn btn-outline btn-sm btn-block" onClick={() => setShowConfirm(true)}>
        Force Settle (Testing)
      </button>
    );
  }

  return (
    <div className="space-y-2 w-full">
      <div className="alert alert-warning text-xs p-2">
        <span>Settlement is irreversible. Choose wisely!</span>
      </div>

      <div className="flex gap-2">
        <button
          className="btn btn-success btn-sm flex-1"
          onClick={() => handleSettle(true)}
          disabled={isPending}
        >
          {isPending ? (
            <span className="loading loading-spinner loading-xs"></span>
          ) : (
            <>
              ✓ Success
              <br />
              <span className="text-xs opacity-70">(Get stake + yield)</span>
            </>
          )}
        </button>

        <button
          className="btn btn-error btn-sm flex-1"
          onClick={() => handleSettle(false)}
          disabled={isPending}
        >
          {isPending ? (
            <span className="loading loading-spinner loading-xs"></span>
          ) : (
            <>
              ✗ Failed
              <br />
              <span className="text-xs opacity-70">(Slash to treasury)</span>
            </>
          )}
        </button>
      </div>

      <button className="btn btn-ghost btn-xs btn-block" onClick={() => setShowConfirm(false)} disabled={isPending}>
        Cancel
      </button>
    </div>
  );
};

