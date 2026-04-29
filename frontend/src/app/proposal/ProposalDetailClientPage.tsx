"use client";

import { notFound } from "next/navigation";
import ProposalDetailView from "@/components/proposals/detail/ProposalDetailView";
import { useProposalDetails } from "@/hooks";

type ProposalDetailClientPageProps = {
  proposalPublicKey: string;
};

export const ProposalDetailClientPage = ({
  proposalPublicKey,
}: ProposalDetailClientPageProps) => {

  const {
    data: proposalData,
    isFetched,
    isLoading,
  } = useProposalDetails(proposalPublicKey);

  if (!proposalData && isFetched) {
    notFound();
  }

  return (
    <main className="space-y-8 py-8">
      <ProposalDetailView proposal={proposalData} isLoading={isLoading} />
    </main>
  );
};
