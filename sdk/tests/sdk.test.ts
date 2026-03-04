import assert from 'node:assert/strict';
import test from 'node:test';

import { FractalMindSDK } from '../src';

const PACKAGE_ID = '0x123';
const REGISTRY_ID = '0x456';

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

test('organization.createOrganization builds expected move target', () => {
  const sdk = new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client: new MockSuiClient() as never,
  });

  const tx = sdk.organization.createOrganization({
    name: 'Root Org',
    description: 'Root description',
  });

  assert.equal(
    getMoveCallTarget(tx),
    '0x0000000000000000000000000000000000000000000000000000000000000123::entry::create_organization',
  );
});

test('governance.castVote builds expected move target', () => {
  const sdk = new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client: new MockSuiClient() as never,
  });

  const tx = sdk.governance.castVote({
    proposalId: '0x999',
    voterCertId: '0x888',
    vote: 1,
  });

  assert.equal(
    getMoveCallTarget(tx),
    '0x0000000000000000000000000000000000000000000000000000000000000123::entry::cast_proposal_vote',
  );
});

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

  const sdk = new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client: mockClient as never,
  });

  const org = await sdk.organization.getOrganization('0x100');

  assert.equal(org.name, 'Core');
  assert.equal(org.description, 'Main org');
  assert.equal(org.admin, '0x0000000000000000000000000000000000000000000000000000000000000abc');
  assert.equal(org.agentCount, 5n);
  assert.equal(org.parentOrgId, null);
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

  const sdk = new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client: mockClient as never,
  });

  const cert = await sdk.agent.getAgentCertificate({
    owner: '0x111',
    orgId: '0xbbb',
  });

  assert.ok(cert);
  assert.equal(cert.objectId, '0x00000000000000000000000000000000000000000000000000000000000000c2');
  assert.deepEqual(cert.capabilityTags, ['qa']);
});
