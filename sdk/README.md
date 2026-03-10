# FractalMind Protocol TypeScript SDK

TypeScript SDK for interacting with `fractalmind_protocol` on Sui.

## Features

- Organization: `createOrganization`, `getOrganization`, `updateDescription`
- Agent: `registerAgent`, `getAgentCertificate`, `updateCapabilities`
- Task: `createTask`, `assignTask`, `submitTask`, `verifyTask`, `completeTask`
- Fractal: `createSubOrganization`, `detachSubOrganization`
- Governance: `createProposal`, `castVote`, `executeProposal`

All write methods return a `Transaction` so you can compose multi-step PTBs.

## Install

```bash
cd sdk
npm install
```

## Quick Start

```ts
import { FractalMindSDK } from '@fractalmind-ai/fractalmind-sdk';

const sdk = new FractalMindSDK({
  packageId: '0xYOUR_PACKAGE_ID',
  registryId: '0xYOUR_REGISTRY_ID',
  network: 'testnet',
});

const tx = sdk.organization.createOrganization({
  name: 'Core Org',
  description: 'Fractal root organization',
});

// client.signAndExecuteTransaction example:
// await sdk.client.signAndExecuteTransaction({ signer, transaction: tx });
```

## API Notes

- `registryId` is required for organization/fractal create flows.
- `getAgentCertificate` supports:
  - by object id: `{ certificateId }`
  - by owner address: `{ owner, orgId? }`
- Governance proposal lifecycle on-chain is:
  - `createProposal` -> `startProposalVoting` -> `castVote` -> `finalizeProposalVoting` -> `executeProposal`

## Development

```bash
cd sdk
npm run typecheck
npm run build
npm test
```
