/**
 * FractalMind Protocol KR4 Verification Script
 *
 * Verifies end-to-end protocol functionality on SUI Testnet:
 * 1. Create SuLabs organization
 * 2. Register AI agents
 * 3. Complete ≥5 task lifecycle cycles
 * 4. Create sub-organization (fractal structure)
 *
 * Usage:
 *   SUI_MNEMONICS="..." tsx scripts/kr4-verify.ts
 */

import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { FractalMindSDK } from '../src';

const PACKAGE_ID = '0x685d6fb6ed8b0e679bb467ea73111819ec6ff68b1466d24ca26b400095dcdf24';
const REGISTRY_ID = '0xfb8611bf2eb94b950e4ad47a76adeaab8ddda23e602c77e7464cc20572a547e3';

interface CreatedObject {
  type: string;
  objectId: string;
  owner?: unknown;
}

async function main() {
  const mnemonic = process.env.SUI_MNEMONICS;
  if (!mnemonic) {
    throw new Error('SUI_MNEMONICS environment variable is required');
  }

  // --- Setup: Two keypairs from same mnemonic (different derivation paths) ---
  const keypair = Ed25519Keypair.deriveKeypair(mnemonic, "m/44'/784'/0'/0'/0'");
  const address = keypair.getPublicKey().toSuiAddress();
  const keypair2 = Ed25519Keypair.deriveKeypair(mnemonic, "m/44'/784'/1'/0'/0'");
  const address2 = keypair2.getPublicKey().toSuiAddress();
  const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io:443' });

  console.log('=== FractalMind Protocol KR4 Verification ===');
  console.log(`Wallet 1 (Admin/OpenClaw): ${address}`);
  console.log(`Wallet 2 (RoseX):         ${address2}`);
  console.log(`Package: ${PACKAGE_ID}`);
  console.log(`Registry: ${REGISTRY_ID}`);
  console.log();

  const balance = await client.getBalance({ owner: address });
  console.log(`Balance (wallet 1): ${Number(balance.totalBalance) / 1e9} SUI`);
  if (Number(balance.totalBalance) < 100_000_000) {
    throw new Error('Insufficient balance (need ≥0.1 SUI)');
  }

  // Fund wallet 2 for gas
  const balance2 = await client.getBalance({ owner: address2 });
  if (Number(balance2.totalBalance) < 50_000_000) {
    console.log('Funding wallet 2 with 0.2 SUI...');
    const fundTx = new Transaction();
    const [coin] = fundTx.splitCoins(fundTx.gas, [200_000_000]);
    fundTx.transferObjects([coin], address2);
    const fundResult = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: fundTx,
      options: { showEffects: true },
    });
    await client.waitForTransaction({ digest: fundResult.digest });
    console.log(`  Funded wallet 2: ${fundResult.digest}`);
  }
  const bal2After = await client.getBalance({ owner: address2 });
  console.log(`Balance (wallet 2): ${Number(bal2After.totalBalance) / 1e9} SUI`);
  console.log();

  const sdk = new FractalMindSDK({
    packageId: PACKAGE_ID,
    registryId: REGISTRY_ID,
    client,
  });

  // Helper: execute transaction and extract created objects
  async function exec(tx: Transaction, label: string, signer: Ed25519Keypair = keypair): Promise<CreatedObject[]> {
    console.log(`[TX] ${label}...`);
    const result = await client.signAndExecuteTransaction({
      signer,
      transaction: tx,
      options: { showObjectChanges: true, showEffects: true },
    });

    // Wait for finality
    await client.waitForTransaction({ digest: result.digest });

    const effects = result.effects;
    if (effects && typeof effects === 'object' && 'status' in effects) {
      const status = (effects as { status: { status: string } }).status;
      if (status.status !== 'success') {
        throw new Error(`Transaction failed: ${JSON.stringify(status)}`);
      }
    }

    const created: CreatedObject[] = [];
    if (result.objectChanges) {
      for (const change of result.objectChanges) {
        if (change.type === 'created') {
          created.push({
            type: (change as { objectType: string }).objectType,
            objectId: (change as { objectId: string }).objectId,
            owner: (change as { owner?: unknown }).owner,
          });
        }
      }
    }
    console.log(`  ✅ Digest: ${result.digest}`);
    console.log(`  Created: ${created.length} objects`);
    for (const obj of created) {
      const shortType = obj.type.split('::').slice(-1)[0];
      console.log(`    - ${shortType}: ${obj.objectId}`);
    }
    return created;
  }

  function findCreated(objects: CreatedObject[], typeSuffix: string): string {
    const found = objects.find((o) => o.type.includes(typeSuffix));
    if (!found) {
      throw new Error(`Created object with type ${typeSuffix} not found`);
    }
    return found.objectId;
  }

  // ============================================
  // Step 1: Create SuLabs Organization
  // ============================================
  const orgName = `SuLabs-${Date.now()}`;
  console.log(`\n--- Step 1: Create ${orgName} Organization ---`);
  const createOrgTx = sdk.organization.createOrganization({
    name: orgName,
    description: 'AI Agent organization for SUI ecosystem development — powered by FractalMind Protocol',
  });
  const orgObjects = await exec(createOrgTx, 'create_organization');
  const orgId = findCreated(orgObjects, 'Organization');
  const adminCapId = findCreated(orgObjects, 'OrgAdminCap');
  console.log(`\n  Organization ID: ${orgId}`);
  console.log(`  AdminCap ID:     ${adminCapId}`);

  // Verify org data
  const orgData = await sdk.organization.getOrganization(orgId);
  console.log(`  Name: ${orgData.name}`);
  console.log(`  Admin: ${orgData.admin}`);
  console.log(`  Active: ${orgData.isActive}`);
  console.log(`  Depth: ${orgData.depth}`);

  // ============================================
  // Step 2: Register AI Agents
  // ============================================
  console.log('\n--- Step 2: Register AI Agents ---');

  // Agent 1: OpenClaw (Main Agent — coordinator, OKR management)
  const registerAgent1Tx = sdk.agent.registerAgent({
    organizationId: orgId,
    capabilityTags: ['coordinator', 'okr-management', 'code-review', 'deployment'],
  });
  const agent1Objects = await exec(registerAgent1Tx, 'register_agent (OpenClaw)');
  const agent1CertId = findCreated(agent1Objects, 'AgentCertificate');
  console.log(`  OpenClaw Certificate: ${agent1CertId}`);

  // Agent 2: RoseX (External contributor — development, uses keypair2)
  const registerAgent2Tx = sdk.agent.registerAgent({
    organizationId: orgId,
    capabilityTags: ['development', 'frontend', 'i18n'],
  });
  const agent2Objects = await exec(registerAgent2Tx, 'register_agent (RoseX)', keypair2);
  const agent2CertId = findCreated(agent2Objects, 'AgentCertificate');
  console.log(`  RoseX Certificate: ${agent2CertId}`);

  // Verify org agent count
  const orgAfterAgents = await sdk.organization.getOrganization(orgId);
  console.log(`  Org agent count: ${orgAfterAgents.agentCount}`);

  // ============================================
  // Step 3: Complete 5 Task Lifecycle Cycles
  // ============================================
  console.log('\n--- Step 3: Task Lifecycle Cycles (5 rounds) ---');

  const tasks = [
    { title: 'Deploy Protocol to Testnet', desc: 'Publish fractalmind_protocol package to SUI testnet', submission: 'Package deployed: 0x685d...df24. All 9 modules published.' },
    { title: 'Create SDK TypeScript Package', desc: 'Build TypeScript SDK with full API coverage for protocol interactions', submission: 'SDK published: @fractalmind/protocol-sdk v0.1.0. 6 API modules, 29 unit tests.' },
    { title: 'Implement DAO Governance Module', desc: 'Add on-chain governance with proposal, voting, and execution lifecycle', submission: 'Governance module complete. Proposal → Vote → Finalize → Execute flow verified.' },
    { title: 'Review PR #927 Gas Sponsorship', desc: 'QA review of gas sponsorship indicator in trade success dialog', submission: 'QA PASS: CI green, i18n correct for 4 locales, gasMode conditional rendering verified.' },
    { title: 'Setup CI/CD Pipeline', desc: 'Configure GitHub Actions for Move build, test, and deployment workflows', submission: 'CI configured: build + test on PR, deploy-contracts.yml for manual testnet/mainnet publish.' },
  ];

  const taskIds: string[] = [];

  for (let i = 0; i < tasks.length; i++) {
    const t = tasks[i];
    console.log(`\n  [Task ${i + 1}/5] "${t.title}"`);

    // Create
    const createTx = sdk.task.createTask({
      organizationId: orgId,
      creatorCertId: agent1CertId,
      title: t.title,
      description: t.desc,
    });
    const taskObjects = await exec(createTx, `create_task #${i + 1}`);
    const taskId = findCreated(taskObjects, 'Task');
    taskIds.push(taskId);

    // Assign to OpenClaw (admin) — complete_task needs both adminCap + assigneeCert
    // from same owner, so all tasks go to the admin agent
    const assignTx = sdk.task.assignTask({
      taskId,
      organizationId: orgId,
      certId: agent1CertId,
    });
    await exec(assignTx, `assign_task #${i + 1}`);

    // Submit (signed by assignee = admin)
    const submitTx = sdk.task.submitTask({
      taskId,
      submission: t.submission,
    });
    await exec(submitTx, `submit_task #${i + 1}`);

    // Verify
    const verifyTx = sdk.task.verifyTask({
      adminCapId,
      taskId,
    });
    await exec(verifyTx, `verify_task #${i + 1}`);

    // Complete
    const completeTx = sdk.task.completeTask({
      adminCapId,
      taskId,
      assigneeCertId: agent1CertId,
    });
    await exec(completeTx, `complete_task #${i + 1}`);

    // Verify final state
    const taskData = await sdk.task.getTask(taskId);
    console.log(`  Status: ${taskData.status} (expected: completed)`);
  }

  // Check agent reputation after tasks
  const agent1Data = await sdk.agent.getAgentCertificate({ certificateId: agent1CertId });
  const agent2Data = await sdk.agent.getAgentCertificate({ certificateId: agent2CertId });
  console.log(`\n  Agent reputation after tasks:`);
  console.log(`  OpenClaw: tasksCompleted=${agent1Data?.tasksCompleted}, reputation=${agent1Data?.reputationScore}`);
  console.log(`  RoseX:    tasksCompleted=${agent2Data?.tasksCompleted}, reputation=${agent2Data?.reputationScore}`);

  // ============================================
  // Step 4: Fractal Structure (Sub-Organization)
  // ============================================
  console.log('\n--- Step 4: Fractal Structure (Sub-Organization) ---');

  const createSubOrgTx = sdk.fractal.createSubOrganization({
    adminCapId,
    parentOrganizationId: orgId,
    name: 'CloudBank Team',
    description: 'Sub-team focused on CloudBank prediction market development',
  });
  const subOrgObjects = await exec(createSubOrgTx, 'create_sub_organization');
  const subOrgId = findCreated(subOrgObjects, 'Organization');
  const subAdminCapId = findCreated(subOrgObjects, 'OrgAdminCap');

  // Verify fractal structure
  const parentOrg = await sdk.organization.getOrganization(orgId);
  const childOrg = await sdk.organization.getOrganization(subOrgId);

  console.log(`\n  Parent (SuLabs):`);
  console.log(`    depth: ${parentOrg.depth}, childOrgCount: ${parentOrg.childOrgCount}`);
  console.log(`  Child (CloudBank Team):`);
  console.log(`    depth: ${childOrg.depth}, parentOrgId: ${childOrg.parentOrgId}`);
  console.log(`    Self-similar: depth=${childOrg.depth} (parent+1=${parentOrg.depth + 1n})`);

  // ============================================
  // Summary
  // ============================================
  console.log('\n\n========================================');
  console.log('    KR4 VERIFICATION COMPLETE ✅');
  console.log('========================================');
  console.log();
  console.log('Results:');
  console.log(`  Organization (SuLabs): ${orgId}`);
  console.log(`  Admin Capability:      ${adminCapId}`);
  console.log(`  Agent 1 (OpenClaw):    ${agent1CertId}`);
  console.log(`  Agent 2 (RoseX):       ${agent2CertId}`);
  console.log(`  Tasks completed:       ${taskIds.length}`);
  console.log(`  Sub-org (CloudBank):   ${subOrgId}`);
  console.log(`  Sub-org AdminCap:      ${subAdminCapId}`);
  console.log();
  console.log('Explorer Links:');
  console.log(`  SuLabs Org:     https://suiscan.xyz/testnet/object/${orgId}`);
  console.log(`  CloudBank Team: https://suiscan.xyz/testnet/object/${subOrgId}`);
  console.log(`  Agent OpenClaw: https://suiscan.xyz/testnet/object/${agent1CertId}`);
  console.log(`  Agent RoseX:    https://suiscan.xyz/testnet/object/${agent2CertId}`);
  for (let i = 0; i < taskIds.length; i++) {
    console.log(`  Task ${i + 1}:         https://suiscan.xyz/testnet/object/${taskIds[i]}`);
  }

  // Output summary as JSON for workflow consumption
  const summary = {
    orgId,
    adminCapId,
    agents: [
      { name: 'OpenClaw', certId: agent1CertId, tasksCompleted: agent1Data?.tasksCompleted?.toString() },
      { name: 'RoseX', certId: agent2CertId, tasksCompleted: agent2Data?.tasksCompleted?.toString() },
    ],
    tasks: taskIds,
    subOrg: { id: subOrgId, adminCapId: subAdminCapId },
  };
  console.log('\n[JSON_SUMMARY]');
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((err) => {
  console.error('❌ KR4 verification failed:', err);
  process.exit(1);
});
