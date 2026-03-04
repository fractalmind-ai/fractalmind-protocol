import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { normalizeSuiAddress } from '@mysten/sui/utils';

import type {
  Address,
  FractalMindClientOptions,
  MoveObjectData,
  NetworkName,
  ObjectId,
} from './types';

const DEFAULT_NETWORK: NetworkName = 'testnet';

export class FractalMindClient {
  public readonly client: SuiClient;
  public readonly packageId: ObjectId;
  public readonly registryId?: ObjectId;

  constructor(options: FractalMindClientOptions) {
    this.packageId = normalizeSuiAddress(options.packageId);
    this.registryId = options.registryId ? normalizeSuiAddress(options.registryId) : undefined;

    if (options.client) {
      this.client = options.client;
      return;
    }

    const network = options.network ?? DEFAULT_NETWORK;
    const url = options.fullnodeUrl ?? getFullnodeUrl(network);
    this.client = new SuiClient({ url });
  }

  newTransaction(): Transaction {
    return new Transaction();
  }

  target(entryFunction: string): string {
    return `${this.packageId}::entry::${entryFunction}`;
  }

  resolveRegistryId(registryId?: ObjectId): ObjectId {
    if (registryId) {
      return normalizeSuiAddress(registryId);
    }
    if (this.registryId) {
      return this.registryId;
    }
    throw new Error('Missing registry object id. Pass registryId in call args or client options.');
  }

  useTransaction(tx?: Transaction): Transaction {
    return tx ?? this.newTransaction();
  }

  async getMoveObject(objectId: ObjectId): Promise<MoveObjectData> {
    const response = await this.client.getObject({
      id: objectId,
      options: {
        showContent: true,
        showType: true,
      },
    });

    const parsed = parseMoveObject(response);
    if (!parsed) {
      throw new Error(`Object ${objectId} was not found or is not a Move object.`);
    }
    return parsed;
  }

  async getOwnedMoveObjects(owner: Address, structType: string): Promise<MoveObjectData[]> {
    let cursor: string | null | undefined = null;
    const data: MoveObjectData[] = [];

    do {
      const page = await this.client.getOwnedObjects({
        owner: normalizeSuiAddress(owner),
        filter: { StructType: structType },
        options: {
          showContent: true,
          showType: true,
        },
        cursor,
      });

      for (const item of page.data) {
        const parsed = parseMoveObject(item);
        if (parsed) {
          data.push(parsed);
        }
      }

      cursor = page.hasNextPage ? page.nextCursor : null;
    } while (cursor);

    return data;
  }

  async signAndExecuteTransaction(
    params: Parameters<SuiClient['signAndExecuteTransaction']>[0],
  ): Promise<Awaited<ReturnType<SuiClient['signAndExecuteTransaction']>>> {
    const { signer, transaction } = params as {
      signer?: { getPublicKey?: () => { toSuiAddress: () => string } };
      transaction?: Transaction;
    };

    if (transaction && signer?.getPublicKey) {
      const signerAddress = normalizeSuiAddress(signer.getPublicKey().toSuiAddress());
      const sender = transaction.getData().sender;
      if (!sender || normalizeSuiAddress(sender) !== signerAddress) {
        transaction.setSender(signerAddress);
      }
    }

    return this.client.signAndExecuteTransaction(params);
  }
}

function parseMoveObject(response: unknown): MoveObjectData | null {
  const maybeResponse = response as {
    data?: {
      objectId?: string;
      type?: string;
      content?: {
        dataType?: string;
        type?: string;
        fields?: Record<string, unknown>;
      };
    };
  };

  const data = maybeResponse.data;
  if (!data || !data.content || data.content.dataType !== 'moveObject') {
    return null;
  }

  const objectId = data.objectId;
  const type = data.type ?? data.content.type;
  const fields = data.content.fields;

  if (!objectId || !type || !fields) {
    return null;
  }

  return {
    objectId: normalizeSuiAddress(objectId),
    type,
    fields,
  };
}

export function readString(fields: Record<string, unknown>, key: string): string {
  const value = fields[key];
  if (typeof value !== 'string') {
    throw new Error(`Expected string field '${key}'.`);
  }
  return value;
}

export function readAddress(fields: Record<string, unknown>, key: string): Address {
  const value = readString(fields, key);
  return normalizeSuiAddress(value);
}

export function readBoolean(fields: Record<string, unknown>, key: string): boolean {
  const value = fields[key];
  if (typeof value !== 'boolean') {
    throw new Error(`Expected boolean field '${key}'.`);
  }
  return value;
}

export function readNumber(fields: Record<string, unknown>, key: string): number {
  const value = fields[key];
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    return Number.parseInt(value, 10);
  }
  throw new Error(`Expected numeric field '${key}'.`);
}

export function readBigInt(fields: Record<string, unknown>, key: string): bigint {
  const value = fields[key];
  if (typeof value === 'bigint') {
    return value;
  }
  if (typeof value === 'number') {
    return BigInt(value);
  }
  if (typeof value === 'string') {
    return BigInt(value);
  }
  throw new Error(`Expected bigint-like field '${key}'.`);
}

export function readStringVector(fields: Record<string, unknown>, key: string): string[] {
  const value = fields[key];
  if (!Array.isArray(value)) {
    throw new Error(`Expected array field '${key}'.`);
  }
  return value.map((item) => {
    if (typeof item !== 'string') {
      throw new Error(`Expected string element in '${key}'.`);
    }
    return item;
  });
}

export function readOptionId(fields: Record<string, unknown>, key: string): ObjectId | null {
  const value = fields[key];
  if (!value || typeof value !== 'object') {
    return null;
  }

  const vec = (value as { vec?: unknown }).vec;
  if (!Array.isArray(vec) || vec.length === 0) {
    return null;
  }

  const first = vec[0];
  if (typeof first === 'string') {
    return normalizeSuiAddress(first);
  }

  return null;
}

export function toBigInt(value: bigint | number | string): bigint {
  if (typeof value === 'bigint') {
    return value;
  }
  if (typeof value === 'number') {
    return BigInt(value);
  }
  return BigInt(value);
}
