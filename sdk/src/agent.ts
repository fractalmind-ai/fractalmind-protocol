import { normalizeSuiAddress } from '@mysten/sui/utils';
import type { Transaction } from '@mysten/sui/transactions';

import {
  FractalMindClient,
  readAddress,
  readBigInt,
  readNumber,
  readStringVector,
} from './client';
import type {
  AgentCertificateData,
  GetAgentCertificateInput,
  ObjectId,
  RegisterAgentInput,
  UpdateCapabilitiesInput,
} from './types';

export class AgentApi {
  constructor(private readonly fm: FractalMindClient) {}

  registerAgent(input: RegisterAgentInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('register_agent'),
      arguments: [
        tx.object(input.organizationId),
        tx.pure.vector('string', input.capabilityTags),
      ],
    });

    return tx;
  }

  updateCapabilities(input: UpdateCapabilitiesInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('update_agent_capabilities'),
      arguments: [
        tx.object(input.certificateId),
        tx.pure.vector('string', input.newTags),
      ],
    });

    return tx;
  }

  async getAgentCertificate(input: GetAgentCertificateInput): Promise<AgentCertificateData | null> {
    if ('certificateId' in input) {
      const obj = await this.fm.getMoveObject(input.certificateId);
      if (!obj.type.endsWith('::agent::AgentCertificate')) {
        throw new Error(`Object ${input.certificateId} is not an AgentCertificate.`);
      }
      return this.parseCertificate(obj.objectId, obj.type, obj.fields);
    }

    const objects = await this.fm.getOwnedMoveObjects(
      input.owner,
      `${this.fm.packageId}::agent::AgentCertificate`,
    );

    for (const obj of objects) {
      const parsed = this.parseCertificate(obj.objectId, obj.type, obj.fields);
      if (!input.orgId || parsed.orgId === normalizeSuiAddress(input.orgId)) {
        return parsed;
      }
    }

    return null;
  }

  private parseCertificate(
    objectId: ObjectId,
    type: string,
    fields: Record<string, unknown>,
  ): AgentCertificateData {
    return {
      objectId,
      type,
      orgId: readAddress(fields, 'org_id'),
      agent: readAddress(fields, 'agent'),
      capabilityTags: readStringVector(fields, 'capability_tags'),
      status: readNumber(fields, 'status'),
      tasksCompleted: readBigInt(fields, 'tasks_completed'),
      reputationScore: readBigInt(fields, 'reputation_score'),
    };
  }
}
