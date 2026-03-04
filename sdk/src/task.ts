import type { Transaction } from '@mysten/sui/transactions';

import {
  FractalMindClient,
  readAddress,
  readNumber,
  readOptionId,
  readString,
} from './client';
import type {
  AssignTaskInput,
  CompleteTaskInput,
  CreateTaskInput,
  ObjectId,
  RejectTaskInput,
  SubmitTaskInput,
  TaskData,
  VerifyTaskInput,
} from './types';

export class TaskApi {
  constructor(private readonly fm: FractalMindClient) {}

  createTask(input: CreateTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('create_task'),
      arguments: [
        tx.object(input.organizationId),
        tx.object(input.creatorCertId),
        tx.pure.string(input.title),
        tx.pure.string(input.description),
      ],
    });

    return tx;
  }

  assignTask(input: AssignTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('assign_task'),
      arguments: [
        tx.object(input.taskId),
        tx.object(input.organizationId),
        tx.object(input.certId),
      ],
    });

    return tx;
  }

  submitTask(input: SubmitTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('submit_task'),
      arguments: [
        tx.object(input.taskId),
        tx.pure.string(input.submission),
      ],
    });

    return tx;
  }

  verifyTask(input: VerifyTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('verify_task'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.taskId),
      ],
    });

    return tx;
  }

  completeTask(input: CompleteTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('complete_task'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.taskId),
        tx.object(input.assigneeCertId),
      ],
    });

    return tx;
  }

  rejectTask(input: RejectTaskInput): Transaction {
    const tx = this.fm.useTransaction(input.tx);

    tx.moveCall({
      target: this.fm.target('reject_task'),
      arguments: [
        tx.object(input.adminCapId),
        tx.object(input.taskId),
        tx.object(input.assigneeCertId),
        tx.pure.string(input.reason),
      ],
    });

    return tx;
  }

  async getTask(taskId: ObjectId): Promise<TaskData> {
    const obj = await this.fm.getMoveObject(taskId);

    if (!obj.type.endsWith('::task::Task')) {
      throw new Error(`Object ${taskId} is not a Task.`);
    }

    return {
      objectId: obj.objectId,
      type: obj.type,
      orgId: readAddress(obj.fields, 'org_id'),
      creator: readAddress(obj.fields, 'creator'),
      title: readString(obj.fields, 'title'),
      description: readString(obj.fields, 'description'),
      status: readNumber(obj.fields, 'status'),
      assignee: readOptionId(obj.fields, 'assignee'),
    };
  }
}
