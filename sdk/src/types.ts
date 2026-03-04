import type { SuiClient } from '@mysten/sui/client';
import type { Transaction } from '@mysten/sui/transactions';

export type ObjectId = string;
export type Address = string;
export type U64 = bigint;

export type NetworkName = 'mainnet' | 'testnet' | 'devnet' | 'localnet';
export type VoteOption = 1 | 2 | 3;

export interface FractalMindClientOptions {
  packageId: string;
  registryId?: ObjectId;
  network?: NetworkName;
  fullnodeUrl?: string;
  client?: SuiClient;
}

export interface MoveObjectData {
  objectId: ObjectId;
  type: string;
  fields: Record<string, unknown>;
}

export interface TxBuildOptions {
  tx?: Transaction;
}

export interface OrganizationData {
  objectId: ObjectId;
  type: string;
  name: string;
  description: string;
  admin: Address;
  isActive: boolean;
  agentCount: U64;
  taskCount: U64;
  depth: U64;
  childOrgCount: U64;
  parentOrgId: ObjectId | null;
}

export interface AgentCertificateData {
  objectId: ObjectId;
  type: string;
  orgId: ObjectId;
  agent: Address;
  capabilityTags: string[];
  status: number;
  tasksCompleted: U64;
  reputationScore: U64;
}

export interface TaskData {
  objectId: ObjectId;
  type: string;
  orgId: ObjectId;
  creator: Address;
  title: string;
  description: string;
  status: number;
  assignee: Address | null;
}

export interface ProposalData {
  objectId: ObjectId;
  type: string;
  governanceId: ObjectId;
  orgId: ObjectId;
  creator: Address;
  title: string;
  description: string;
  status: number;
  votingDeadline: U64;
  forVotes: U64;
  againstVotes: U64;
  abstainVotes: U64;
}

export interface CreateOrganizationInput extends TxBuildOptions {
  registryId?: ObjectId;
  name: string;
  description: string;
}

export interface UpdateDescriptionInput extends TxBuildOptions {
  adminCapId: ObjectId;
  organizationId: ObjectId;
  newDescription: string;
}

export interface RegisterAgentInput extends TxBuildOptions {
  organizationId: ObjectId;
  capabilityTags: string[];
}

export interface GetAgentCertificateById {
  certificateId: ObjectId;
}

export interface GetAgentCertificateByOwner {
  owner: Address;
  orgId?: ObjectId;
}

export type GetAgentCertificateInput = GetAgentCertificateById | GetAgentCertificateByOwner;

export interface UpdateCapabilitiesInput extends TxBuildOptions {
  certificateId: ObjectId;
  newTags: string[];
}

export interface CreateTaskInput extends TxBuildOptions {
  organizationId: ObjectId;
  creatorCertId: ObjectId;
  title: string;
  description: string;
}

export interface AssignTaskInput extends TxBuildOptions {
  taskId: ObjectId;
  organizationId: ObjectId;
  certId: ObjectId;
}

export interface SubmitTaskInput extends TxBuildOptions {
  taskId: ObjectId;
  submission: string;
}

export interface VerifyTaskInput extends TxBuildOptions {
  adminCapId: ObjectId;
  taskId: ObjectId;
}

export interface CompleteTaskInput extends TxBuildOptions {
  adminCapId: ObjectId;
  taskId: ObjectId;
  assigneeCertId: ObjectId;
}

export interface RejectTaskInput extends TxBuildOptions {
  adminCapId: ObjectId;
  taskId: ObjectId;
  assigneeCertId: ObjectId;
  reason: string;
}

export interface CreateSubOrganizationInput extends TxBuildOptions {
  adminCapId: ObjectId;
  parentOrganizationId: ObjectId;
  registryId?: ObjectId;
  name: string;
  description: string;
}

export interface DetachSubOrganizationInput extends TxBuildOptions {
  parentAdminCapId: ObjectId;
  childAdminCapId: ObjectId;
  parentOrganizationId: ObjectId;
  childOrganizationId: ObjectId;
}

export interface CreateGovernanceInput extends TxBuildOptions {
  adminCapId: ObjectId;
  organizationId: ObjectId;
}

export interface CreateProposalInput extends TxBuildOptions {
  governanceId: ObjectId;
  organizationId: ObjectId;
  proposerCertId: ObjectId;
  title: string;
  description: string;
  votingDeadlineMs: bigint | number | string;
  executionPayload: number[];
}

export interface StartProposalVotingInput extends TxBuildOptions {
  adminCapId: ObjectId;
  governanceId: ObjectId;
  proposalId: ObjectId;
}

export interface CastVoteInput extends TxBuildOptions {
  proposalId: ObjectId;
  voterCertId: ObjectId;
  vote: VoteOption;
}

export interface FinalizeProposalVotingInput extends TxBuildOptions {
  adminCapId: ObjectId;
  governanceId: ObjectId;
  proposalId: ObjectId;
}

export interface CloseProposalVotingInput extends TxBuildOptions {
  adminCapId: ObjectId;
  governanceId: ObjectId;
  proposalId: ObjectId;
}

export interface ExecuteProposalInput extends TxBuildOptions {
  adminCapId: ObjectId;
  governanceId: ObjectId;
  proposalId: ObjectId;
}
