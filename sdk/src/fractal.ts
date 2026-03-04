import type { Transaction } from '@mysten/sui/transactions';

import { FractalMindClient } from './client';
import type {
  CreateSubOrganizationInput,
  DetachSubOrganizationInput,
} from './types';

export class FractalApi {
  constructor(private readonly fm: FractalMindClient) {}

  createSubOrganization(input: CreateSubOrganizationInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('create_sub_organization'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(this.fm.resolveRegistryId(input.registryId)),
        tx.object(input.parentOrganizationId),
        tx.pure.string(input.name),
        tx.pure.string(input.description),
      ],
    });

    return tx;
  }

  detachSubOrganization(input: DetachSubOrganizationInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('detach_sub_organization'),
      arguments: [
        tx.object(input.parentAdminCapId),
        tx.object(input.childAdminCapId),
        tx.object(input.parentOrganizationId),
        tx.object(input.childOrganizationId),
      ],
    });

    return tx;
  }
}
