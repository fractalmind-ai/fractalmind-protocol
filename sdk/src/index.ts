import { AgentApi } from './agent';
import { FractalMindClient } from './client';
import { FractalApi } from './fractal';
import { GovernanceApi } from './governance';
import { OrganizationApi } from './organization';
import { TaskApi } from './task';
import type { FractalMindClientOptions } from './types';

export class FractalMindSDK {
  public readonly client: FractalMindClient;
  public readonly organization: OrganizationApi;
  public readonly agent: AgentApi;
  public readonly task: TaskApi;
  public readonly fractal: FractalApi;
  public readonly governance: GovernanceApi;

  constructor(options: FractalMindClientOptions) {
    this.client = new FractalMindClient(options);
    this.organization = new OrganizationApi(this.client);
    this.agent = new AgentApi(this.client);
    this.task = new TaskApi(this.client);
    this.fractal = new FractalApi(this.client);
    this.governance = new GovernanceApi(this.client);
  }
}

export { FractalMindClient } from './client';
export { OrganizationApi } from './organization';
export { AgentApi } from './agent';
export { TaskApi } from './task';
export { FractalApi } from './fractal';
export { GovernanceApi } from './governance';

export type {
  Address,
  AgentCertificateData,
  AssignTaskInput,
  CastVoteInput,
  CloseProposalVotingInput,
  CompleteTaskInput,
  CreateGovernanceInput,
  CreateOrganizationInput,
  CreateProposalInput,
  CreateSubOrganizationInput,
  CreateTaskInput,
  DetachSubOrganizationInput,
  ExecuteProposalInput,
  FinalizeProposalVotingInput,
  FractalMindClientOptions,
  GetAgentCertificateInput,
  MoveObjectData,
  NetworkName,
  ObjectId,
  OrganizationData,
  ProposalData,
  RejectTaskInput,
  RegisterAgentInput,
  StartProposalVotingInput,
  SubmitTaskInput,
  TaskData,
  TxBuildOptions,
  U64,
  UpdateCapabilitiesInput,
  UpdateDescriptionInput,
  VerifyTaskInput,
  VoteOption,
} from './types';
