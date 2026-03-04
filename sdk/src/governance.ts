import type { Transaction } from '@mysten/sui/transactions';

import {
  FractalMindClient,
  readAddress,
  readBigInt,
  readNumber,
  readString,
  toBigInt,
} from './client';
import type {
  CastVoteInput,
  CreateGovernanceInput,
  CreateProposalInput,
  ExecuteProposalInput,
  FinalizeProposalVotingInput,
  ObjectId,
  ProposalData,
  StartProposalVotingInput,
} from './types';

export class GovernanceApi {
  constructor(private readonly fm: FractalMindClient) {}

  createGovernance(input: CreateGovernanceInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('create_governance'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.organizationId),
      ],
    });

    return tx;
  }

  createProposal(input: CreateProposalInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('create_proposal'),
      arguments: [
        tx.object(input.governanceId),
        tx.object(input.organizationId),
        tx.object(input.proposerCertId),
        tx.pure.string(input.title),
        tx.pure.string(input.description),
        tx.pure.u64(toBigInt(input.votingDeadlineMs)),
        tx.pure.vector('u8', input.executionPayload),
      ],
    });

    return tx;
  }

  startProposalVoting(input: StartProposalVotingInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('start_proposal_voting'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.governanceId),
        tx.object(input.proposalId),
      ],
    });

    return tx;
  }

  castVote(input: CastVoteInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('cast_proposal_vote'),
      arguments: [
        tx.object(input.proposalId),
        tx.object(input.voterCertId),
        tx.pure.u8(input.vote),
      ],
    });

    return tx;
  }

  finalizeProposalVoting(input: FinalizeProposalVotingInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('finalize_proposal_voting'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.governanceId),
        tx.object(input.proposalId),
      ],
    });

    return tx;
  }

  executeProposal(input: ExecuteProposalInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('execute_proposal'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.governanceId),
        tx.object(input.proposalId),
      ],
    });

    return tx;
  }

  async getProposal(proposalId: ObjectId): Promise<ProposalData> {
    const obj = await this.fm.getMoveObject(proposalId);

    if (!obj.type.endsWith('::governance::Proposal')) {
      throw new Error(`Object ${proposalId} is not a Proposal.`);
    }

    return {
      objectId: obj.objectId,
      type: obj.type,
      governanceId: readAddress(obj.fields, 'governance_id'),
      orgId: readAddress(obj.fields, 'org_id'),
      creator: readAddress(obj.fields, 'creator'),
      title: readString(obj.fields, 'title'),
      description: readString(obj.fields, 'description'),
      status: readNumber(obj.fields, 'status'),
      votingDeadline: readBigInt(obj.fields, 'voting_deadline'),
      forVotes: readBigInt(obj.fields, 'for_votes'),
      againstVotes: readBigInt(obj.fields, 'against_votes'),
      abstainVotes: readBigInt(obj.fields, 'abstain_votes'),
    };
  }
}
