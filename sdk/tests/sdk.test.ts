import assert from 'node:assert/strict';
import test from 'node:test';

import { FractalMindSDK } from '../src';

const PACKAGE_ID = '0x123';
const REGISTRY_ID = '0x456';
const TARGET_PREFIX =
  '0x0000000000000000000000000000000000000000000000000000000000000123::entry::';

class MockSuiClient {
  constructor(
    private readonly objectMap: Record<string, unknown> = {},
    private readonly ownedObjects: unknown[] = [],
  ) {}

  async getObject(params: { id: string }): Promise<unknown> {
    return this.objectMap[params.id] ?? { data: null };
  }

  async getOwnedObjects(): Promise<unknown> {
    return {
      data: this.ownedObjects,
      hasNextPage: false,
      nextCursor: null,
    };
  }

  async signAndExecuteTransaction(): Promise<unknown> {
    return { digest: '0xabc' };
  }
}

function newSdk(client: MockSuiClient = new MockSuiClient()): FractalMindSDK {
  return new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client: client as never,
  });
}

function getMoveCallTarget(tx: { getData: () => unknown }): string {
  const data = tx.getData() as { commands?: unknown[] };
  const first = data.commands?.[0] as
    | {
        $kind?: string;
        MoveCall?: {
          target?: string;
          package?: string;
          module?: string;
          function?: string;
        };
      }
    | { kind?: string; target?: string }
    | undefined;

  if (!first) {
    throw new Error('No command found in transaction.');
  }

  if (first.$kind === 'MoveCall' && first.MoveCall) {
    if (first.MoveCall.target) {
      return first.MoveCall.target;
    }
    const pkg = first.MoveCall.package;
    const module = first.MoveCall.module;
    const fn = first.MoveCall.function;
    if (pkg && module && fn) {
      return `${pkg}::${module}::${fn}`;
    }
  }

  if (first.kind === 'MoveCall' && first.target) {
    return first.target;
  }

  throw new Error('First command is not MoveCall.');
}

function assertMoveTarget(
  tx: { getData: () => unknown },
  expectedFunction: string,
): void {
  assert.equal(getMoveCallTarget(tx), `${TARGET_PREFIX}${expectedFunction}`);
}

const moveCallCases: Array<{
  name: string;
  expectedFunction: string;
  build: (sdk: FractalMindSDK) => { getData: () => unknown };
}> = [
  {
    name: 'organization.createOrganization',
    expectedFunction: 'create_organization',
    build: (sdk) =>
      sdk.organization.createOrganization({
        name: 'Root Org',
        description: 'Root description',
      }),
  },
  {
    name: 'organization.updateDescription',
    expectedFunction: 'update_org_description',
    build: (sdk) =>
      sdk.organization.updateDescription({
        adminCapId: '0x11',
        organizationId: '0x12',
        newDescription: 'Updated description',
      }),
  },
  {
    name: 'agent.registerAgent',
    expectedFunction: 'register_agent',
    build: (sdk) =>
      sdk.agent.registerAgent({
        organizationId: '0x21',
        capabilityTags: ['dev', 'qa'],
      }),
  },
  {
    name: 'agent.updateCapabilities',
    expectedFunction: 'update_agent_capabilities',
    build: (sdk) =>
      sdk.agent.updateCapabilities({
        certificateId: '0x22',
        newTags: ['ops'],
      }),
  },
  {
    name: 'task.createTask',
    expectedFunction: 'create_task',
    build: (sdk) =>
      sdk.task.createTask({
        organizationId: '0x31',
        creatorCertId: '0x32',
        title: 'Task title',
        description: 'Task description',
      }),
  },
  {
    name: 'task.assignTask',
    expectedFunction: 'assign_task',
    build: (sdk) =>
      sdk.task.assignTask({
        taskId: '0x33',
        organizationId: '0x31',
        certId: '0x32',
      }),
  },
  {
    name: 'task.submitTask',
    expectedFunction: 'submit_task',
    build: (sdk) =>
      sdk.task.submitTask({
        taskId: '0x33',
        submission: 'Submission payload',
      }),
  },
  {
    name: 'task.verifyTask',
    expectedFunction: 'verify_task',
    build: (sdk) =>
      sdk.task.verifyTask({
        adminCapId: '0x34',
        taskId: '0x33',
      }),
  },
  {
    name: 'task.completeTask',
    expectedFunction: 'complete_task',
    build: (sdk) =>
      sdk.task.completeTask({
        adminCapId: '0x34',
        taskId: '0x33',
        assigneeCertId: '0x35',
      }),
  },
  {
    name: 'task.rejectTask',
    expectedFunction: 'reject_task',
    build: (sdk) =>
      sdk.task.rejectTask({
        adminCapId: '0x34',
        taskId: '0x33',
        assigneeCertId: '0x35',
        reason: 'Needs rework',
      }),
  },
  {
    name: 'fractal.createSubOrganization',
    expectedFunction: 'create_sub_organization',
    build: (sdk) =>
      sdk.fractal.createSubOrganization({
        adminCapId: '0x41',
        parentOrganizationId: '0x42',
        name: 'Child Org',
        description: 'Child Description',
      }),
  },
  {
    name: 'fractal.detachSubOrganization',
    expectedFunction: 'detach_sub_organization',
    build: (sdk) =>
      sdk.fractal.detachSubOrganization({
        parentAdminCapId: '0x43',
        childAdminCapId: '0x44',
        parentOrganizationId: '0x42',
        childOrganizationId: '0x45',
      }),
  },
  {
    name: 'governance.createGovernance',
    expectedFunction: 'create_governance',
    build: (sdk) =>
      sdk.governance.createGovernance({
        adminCapId: '0x51',
        organizationId: '0x52',
      }),
  },
  {
    name: 'governance.createProposal',
    expectedFunction: 'create_proposal',
    build: (sdk) =>
      sdk.governance.createProposal({
        governanceId: '0x53',
        organizationId: '0x52',
        proposerCertId: '0x54',
        title: 'Proposal title',
        description: 'Proposal description',
        votingDeadlineMs: 1234n,
        executionPayload: [1, 2, 3],
      }),
  },
  {
    name: 'governance.startProposalVoting',
    expectedFunction: 'start_proposal_voting',
    build: (sdk) =>
      sdk.governance.startProposalVoting({
        adminCapId: '0x51',
        governanceId: '0x53',
        proposalId: '0x55',
      }),
  },
  {
    name: 'governance.castVote',
    expectedFunction: 'cast_proposal_vote',
    build: (sdk) =>
      sdk.governance.castVote({
        proposalId: '0x55',
        voterCertId: '0x56',
        vote: 1,
      }),
  },
  {
    name: 'governance.finalizeProposalVoting',
    expectedFunction: 'finalize_proposal_voting',
    build: (sdk) =>
      sdk.governance.finalizeProposalVoting({
        adminCapId: '0x51',
        governanceId: '0x53',
        proposalId: '0x55',
      }),
  },
  {
    name: 'governance.closeProposalVoting',
    expectedFunction: 'close_proposal_voting',
    build: (sdk) =>
      sdk.governance.closeProposalVoting({
        adminCapId: '0x51',
        governanceId: '0x53',
        proposalId: '0x55',
      }),
  },
  {
    name: 'governance.executeProposal',
    expectedFunction: 'execute_proposal',
    build: (sdk) =>
      sdk.governance.executeProposal({
        adminCapId: '0x51',
        governanceId: '0x53',
        proposalId: '0x55',
      }),
  },
];

for (const c of moveCallCases) {
  test(`${c.name} builds expected move target`, () => {
    const sdk = newSdk();
    const tx = c.build(sdk);
    assertMoveTarget(tx, c.expectedFunction);
  });
}

test('organization.getOrganization parses move object fields', async () => {
  const mockClient = new MockSuiClient({
    '0x100': {
      data: {
        objectId: '0x100',
        type: '0x123::organization::Organization',
        content: {
          dataType: 'moveObject',
          fields: {
            name: 'Core',
            description: 'Main org',
            admin: '0xabc',
            is_active: true,
            agent_count: '5',
            task_count: '7',
            depth: '0',
            child_org_count: '2',
            parent_org: { vec: [] },
          },
        },
      },
    },
  });

  const sdk = newSdk(mockClient);
  const org = await sdk.organization.getOrganization('0x100');

  assert.equal(org.name, 'Core');
  assert.equal(org.description, 'Main org');
  assert.equal(org.admin, '0x0000000000000000000000000000000000000000000000000000000000000abc');
  assert.equal(org.agentCount, 5n);
  assert.equal(org.parentOrgId, null);
});

test('task.getTask parses move object fields', async () => {
  const mockClient = new MockSuiClient({
    '0x200': {
      data: {
        objectId: '0x200',
        type: '0x123::task::Task',
        content: {
          dataType: 'moveObject',
          fields: {
            org_id: '0xaaa',
            creator: '0xbbb',
            title: 'T1',
            description: 'Task description',
            status: '2',
            assignee: { vec: ['0xccc'] },
          },
        },
      },
    },
  });

  const sdk = newSdk(mockClient);
  const task = await sdk.task.getTask('0x200');

  assert.equal(task.title, 'T1');
  assert.equal(task.status, 2);
  assert.equal(task.orgId, '0x0000000000000000000000000000000000000000000000000000000000000aaa');
  assert.equal(task.assignee, '0x0000000000000000000000000000000000000000000000000000000000000ccc');
});

test('governance.getProposal parses move object fields', async () => {
  const mockClient = new MockSuiClient({
    '0x300': {
      data: {
        objectId: '0x300',
        type: '0x123::governance::Proposal',
        content: {
          dataType: 'moveObject',
          fields: {
            governance_id: '0x001',
            org_id: '0x002',
            creator: '0x003',
            title: 'P1',
            description: 'Proposal description',
            status: '1',
            voting_deadline: '1700000000000',
            for_votes: '10',
            against_votes: '3',
            abstain_votes: '2',
          },
        },
      },
    },
  });

  const sdk = newSdk(mockClient);
  const proposal = await sdk.governance.getProposal('0x300');

  assert.equal(proposal.title, 'P1');
  assert.equal(proposal.status, 1);
  assert.equal(proposal.forVotes, 10n);
  assert.equal(proposal.againstVotes, 3n);
  assert.equal(proposal.abstainVotes, 2n);
});

test('agent.getAgentCertificate resolves by owner and org id', async () => {
  const mockClient = new MockSuiClient(
    {},
    [
      {
        data: {
          objectId: '0xc1',
          type: '0x123::agent::AgentCertificate',
          content: {
            dataType: 'moveObject',
            fields: {
              org_id: '0xaaa',
              agent: '0x111',
              capability_tags: ['dev'],
              status: '0',
              tasks_completed: '1',
              reputation_score: '2',
            },
          },
        },
      },
      {
        data: {
          objectId: '0xc2',
          type: '0x123::agent::AgentCertificate',
          content: {
            dataType: 'moveObject',
            fields: {
              org_id: '0xbbb',
              agent: '0x111',
              capability_tags: ['qa'],
              status: '0',
              tasks_completed: '2',
              reputation_score: '3',
            },
          },
        },
      },
    ],
  );

  const sdk = newSdk(mockClient);
  const cert = await sdk.agent.getAgentCertificate({
    owner: '0x111',
    orgId: '0xbbb',
  });

  assert.ok(cert);
  assert.equal(cert.objectId, '0x00000000000000000000000000000000000000000000000000000000000000c2');
  assert.deepEqual(cert.capabilityTags, ['qa']);
});
