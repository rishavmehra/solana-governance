import { Suspense } from "react";
import { notFound } from "next/navigation";
import { captureException } from "@sentry/nextjs";
import { ProposalDetailClientPage } from "../ProposalDetailClientPage";

type ProposalPageProps = {
  params: Promise<{
    proposalPk?: string;
  }>;
};

export default async function ProposalPage({ params }: ProposalPageProps) {
  const resolvedParams = await params;
  const proposalPublicKey = resolvedParams.proposalPk;

  if (!proposalPublicKey || typeof proposalPublicKey !== "string") {
    captureException(new Error("Invalid proposalPublicKey route param"));
    notFound();
  }

  return (
    <Suspense fallback={null /* TODO: or a skeleton */}>
      <ProposalDetailClientPage proposalPublicKey={proposalPublicKey} />
    </Suspense>
  );
}
