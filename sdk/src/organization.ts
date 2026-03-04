import type { Transaction } from '@mysten/sui/transactions';

import {
  FractalMindClient,
  readAddress,
  readBigInt,
  readBoolean,
  readOptionId,
  readString,
} from './client';
import type {
  CreateOrganizationInput,
  ObjectId,
  OrganizationData,
  UpdateDescriptionInput,
} from './types';

export class OrganizationApi {
  constructor(private readonly fm: FractalMindClient) {}

  createOrganization(input: CreateOrganizationInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('create_organization'),
      arguments: [
        tx.object(this.fm.resolveRegistryId(input.registryId)),
        tx.pure.string(input.name),
        tx.pure.string(input.description),
      ],
    });

    return tx;
  }

  updateDescription(input: UpdateDescriptionInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('update_org_description'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.organizationId),
        tx.pure.string(input.newDescription),
      ],
    });

    return tx;
  }

  async getOrganization(organizationId: ObjectId): Promise<OrganizationData> {
    const obj = await this.fm.getMoveObject(organizationId);

    if (!obj.type.endsWith('::organization::Organization')) {
      throw new Error(`Object ${organizationId} is not an Organization.`);
    }

    return {
      objectId: obj.objectId,
      type: obj.type,
      name: readString(obj.fields, 'name'),
      description: readString(obj.fields, 'description'),
      admin: readAddress(obj.fields, 'admin'),
      isActive: readBoolean(obj.fields, 'is_active'),
      agentCount: readBigInt(obj.fields, 'agent_count'),
      taskCount: readBigInt(obj.fields, 'task_count'),
      depth: readBigInt(obj.fields, 'depth'),
      childOrgCount: readBigInt(obj.fields, 'child_org_count'),
      parentOrgId: readOptionId(obj.fields, 'parent_org'),
    };
  }
}
