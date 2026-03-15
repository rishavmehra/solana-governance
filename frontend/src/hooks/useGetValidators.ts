import { useEndpoint } from "@/contexts/EndpointContext";
import { getStakeWizValidators } from "@/data";
import { Validator, Validators } from "@/types";
import { Connection, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { useQuery } from "@tanstack/react-query";

export const useGetValidators = () => {
  const { endpointUrl: endpoint } = useEndpoint();

  return useQuery({
    queryKey: ["validators", endpoint],
    staleTime: 1000 * 120, // 2 minutes
    queryFn: () => getValidators(endpoint),
  });
};

const getValidators = async (endpoint: string): Promise<Validators> => {
  const connection = new Connection(endpoint, "confirmed");

  const [stakeWizValidators, voteAccounts] = await Promise.allSettled([
    getStakeWizValidators(),
    connection.getVoteAccounts(),
  ]);

  if (
    stakeWizValidators.status === "fulfilled" &&
    voteAccounts.status === "fulfilled"
  ) {
    const allVotes = [
      ...voteAccounts.value.current,
      ...voteAccounts.value.delinquent,
    ];

    // For each RPC vote account: votePubkey = vote account address, nodePubkey = validator identity.
    // StakeWiz vote_identity is the vote account address — match to vote.votePubkey, not nodePubkey.
    let unknownCount = 0;
    const validators = allVotes.map((vote) => {
      const voteAccountAddress = vote.votePubkey;
      const matchedValidator = stakeWizValidators.value.data.find(
        (v) => v.vote_identity === voteAccountAddress,
      );

      if (matchedValidator) {
        // StakeWiz returns activated_stake in SOL; normalize to lamports.
        const activatedStakeLamports = Math.round(
          matchedValidator.activated_stake * LAMPORTS_PER_SOL,
        );
        return {
          ...matchedValidator,
          activated_stake: activatedStakeLamports,
        };
      }
      unknownCount++;
      const unknownValidator: Validator = {
        name: `Unknown validator #${unknownCount}`,
        activated_stake: vote.activatedStake,
        version: "-",
        description: "",
        asn: "-",
        vote_identity: voteAccountAddress,
        identity: vote.nodePubkey,
        commission: vote.commission,
        epoch_credits: vote.epochCredits?.[0]?.[0] || 0,
        last_vote: vote.lastVote,
      };
      return unknownValidator;
    });
    return validators;
  }

  return [];
};
