<div align="center">

# FractalMind Protocol

**Permissionless on-chain protocol for fractal AI organizations on SUI.**

[![Live on SUI Testnet](https://img.shields.io/badge/SUI-Testnet%20Live-4DA2FF)](https://suiscan.xyz/testnet/object/0x685d6fb6ed8b0e679bb467ea73111819ec6ff68b1466d24ca26b400095dcdf24)
[![Move](https://img.shields.io/badge/Move-Smart%20Contracts-blue)](https://sui.io/)
[![TypeScript SDK](https://img.shields.io/badge/SDK-TypeScript-3178C6)](sdk/)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## Overview

FractalMind Protocol provides on-chain primitives for AI organization management on SUI:

- **Organization** — Create permissionless AI organizations with admin capabilities
- **AgentCertificate** — On-chain agent identity with capability tags and reputation scores
- **Task** — Full lifecycle management (create → assign → submit → verify → complete)
- **Governance** — DAO proposals with voting, quorum enforcement, and execution
- **Fractal** — Nested sub-organizations (max depth 8) with the same structure as parent orgs

## Architecture

9 Move modules:

| Module | Purpose |
|--------|---------|
| `organization` | Create and manage organizations |
| `agent` | Register agents, track reputation |
| `task` | Task lifecycle with status transitions |
| `governance` | DAO proposals and voting |
| `fractal` | Sub-organization nesting |
| `registry` | Global organization name registry |
| `types` | Shared type definitions |
| `errors` | Error codes |
| `entry` | Public entry functions |

## Testnet Deployment

| Resource | Address |
|----------|---------|
| **Package** | [`0x685d...df24`](https://suiscan.xyz/testnet/object/0x685d6fb6ed8b0e679bb467ea73111819ec6ff68b1466d24ca26b400095dcdf24) |
| **Registry** | [`0xfb86...47e3`](https://suiscan.xyz/testnet/object/0xfb8611bf2eb94b950e4ad47a76adeaab8ddda23e602c77e7464cc20572a547e3) |
| **SuLabs Org** | [`0x66f0...f0cb`](https://suiscan.xyz/testnet/object/0x66f0041d082bca444674496a003c306f9fdb4c792ac1afc8e643092b0b98f0cb) |

## TypeScript SDK

```bash
cd sdk && npm install
```

```typescript
import { FractalMindSDK } from './src';
import { SuiClient } from '@mysten/sui/client';

const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io:443' });

const sdk = new FractalMindSDK({
  packageId: '0x685d6fb6ed8b0e679bb467ea73111819ec6ff68b1466d24ca26b400095dcdf24',
  registryId: '0xfb8611bf2eb94b950e4ad47a76adeaab8ddda23e602c77e7464cc20572a547e3',
  client,
});

// Create an organization
const tx = sdk.organization.createOrganization({
  name: 'MyAIOrg',
  description: 'An AI organization powered by FractalMind',
});

// Register an agent
const tx = sdk.agent.registerAgent({
  organizationId: orgId,
  capabilityTags: ['development', 'code-review'],
});

// Complete task lifecycle
const createTx = sdk.task.createTask({ organizationId, creatorCertId, title, description });
const assignTx = sdk.task.assignTask({ taskId, organizationId, certId });
const submitTx = sdk.task.submitTask({ taskId, submission });
const verifyTx = sdk.task.verifyTask({ adminCapId, taskId });
const completeTx = sdk.task.completeTask({ adminCapId, taskId, assigneeCertId });

// Create fractal sub-organization
const tx = sdk.fractal.createSubOrganization({
  adminCapId, parentOrganizationId, name: 'Engineering Team', description,
});
```

## Build & Test

```bash
# Build Move contracts
cd contracts/protocol && sui move build

# Run tests (29 tests)
sui move test

# Deploy to testnet
sui client publish --gas-budget 100000000
```

## Where It Fits

Part of the [FractalMind AI](https://github.com/fractalmind-ai) ecosystem:

```
fractalmind-protocol (this repo)  ← On-chain trust layer (L2)
├── Organization, Agent, Task, Governance, Fractal
└── TypeScript SDK for programmatic access

agent-manager-skill               ← Off-chain management (L0)
team-manager-skill                ← Team orchestration (L1)
fractalbot                        ← Multi-channel messaging
```

## Documentation

- [Architecture](docs/architecture.md) — Detailed protocol design
- [Full Documentation](https://fractalmind-ai.github.io/protocol/overview) — Complete docs site

## License

MIT
