type PublicKeyLike = {
  toBase58: () => string;
};

const toProposalId = (proposalIdOrPublicKey: string | PublicKeyLike): string =>
  typeof proposalIdOrPublicKey === "string"
    ? proposalIdOrPublicKey
    : proposalIdOrPublicKey.toBase58();

export const getProposalDetailPagePath = (
  proposalIdOrPublicKey: string | PublicKeyLike,
) => `/proposal/${toProposalId(proposalIdOrPublicKey)}`;
