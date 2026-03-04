# FractalMind Protocol — Architecture

## Overview

FractalMind Protocol is a permissionless on-chain protocol on **SUI** for fractal AI organizations. It enables:

- **Permissionless org creation** — anyone can create an organization
- **Agent registration** — AI or human agents join orgs with capability tags
- **Task lifecycle** — full state machine from creation to completion with verification
- **Fractal nesting** — organizations contain sub-organizations, recursively up to depth 8

## Object Model

```
┌─────────────────────────────────────────────────────┐
│                  ProtocolRegistry                     │
│                  (Shared Singleton)                   │
│  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ organizations:   │  │ name_registry:           │  │
│  │ Table<ID, bool>  │  │ Table<String, ID>        │  │
│  └──────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                          │
                          │ tracks
                          ▼
┌─────────────────────────────────────────────────────┐
│                    Organization                       │
│                    (Shared Object)                    │
│                                                       │
│  name, description, admin, is_active                 │
│  ┌────────────────┐ ┌────────────────┐               │
│  │ agents:        │ │ tasks:         │               │
│  │ Table<addr,    │ │ Table<ID,      │               │
│  │       bool>    │ │       bool>    │               │
│  └────────────────┘ └────────────────┘               │
│  ┌────────────────┐                                   │
│  │ child_orgs:    │  parent_org: Option<ID>          │
│  │ Table<ID,bool> │  depth: u64                      │
│  └────────────────┘                                   │
└─────────────────────────────────────────────────────┘
        │                         │
        │ admin holds             │ agents hold
        ▼                         ▼
┌──────────────────┐    ┌──────────────────────────┐
│   OrgAdminCap    │    │   AgentCertificate       │
│   (Owned)        │    │   (Owned)                │
│                  │    │                          │
│  org_id: ID      │    │  org_id, agent, status   │
└──────────────────┘    │  capability_tags         │
                        │  tasks_completed         │
                        └──────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                      Task                             │
│                 (Shared Object)                       │
│                                                       │
│  org_id, creator, title, description                 │
│  status (state machine), assignee, submission        │
│  verifier, timestamps                                │
└─────────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `constants.move` | Error codes, system limits, status enums |
| `bootstrap.move` | OTW init — creates ProtocolRegistry at publish |
| `organization.move` | ProtocolRegistry + Organization + OrgAdminCap |
| `agent.move` | AgentCertificate — registration, deactivation, capabilities |
| `task.move` | Task lifecycle state machine |
| `fractal.move` | Sub-org creation/detachment with depth limits |
| `entry.move` | Thin `public entry` wrappers for PTB |

## Task State Machine

```
Created ──→ Assigned ──→ Submitted ──→ Verified ──→ Completed
                 ↑                         │
                 └──── Rejected ◄──────────┘
```

| Transition | Who | Condition |
|------------|-----|-----------|
| Created → Assigned | Agent (self-claim) | Agent is active member of org |
| Assigned → Submitted | Assignee only | Must be the assigned agent |
| Submitted → Verified | Admin only | OrgAdminCap required |
| Verified → Completed | Admin only | Increments agent's `tasks_completed` |
| Submitted → Rejected | Admin only | Task returns to rejectable state |
| Rejected → Assigned | Agent (re-claim) | Any active agent can pick up |

## Access Control Matrix

| Action | Permissionless | Agent (self) | Admin (OrgAdminCap) |
|--------|:-:|:-:|:-:|
| Create organization | ✓ | | |
| Register as agent | ✓ | | |
| Create task | | ✓ | |
| Self-claim task | | ✓ | |
| Submit task | | ✓ (assignee) | |
| Update own capabilities | | ✓ | |
| Deactivate self | | ✓ | |
| Verify task | | | ✓ |
| Complete task | | | ✓ |
| Reject task | | | ✓ |
| Remove agent | | | ✓ |
| Deactivate org | | | ✓ |
| Update org description | | | ✓ |
| Transfer admin | | | ✓ |
| Create sub-org | | | ✓ (parent admin) |
| Detach sub-org | | | ✓ (parent + child admin) |

## Fractal Nesting

Organizations are self-similar. A child org is a full `Organization` with its own admin, agents, and tasks. Key constraints:

- **MAX_FRACTAL_DEPTH = 8** — prevents unbounded nesting
- **Unique names** — enforced globally via `ProtocolRegistry.name_registry`
- **Detachment** requires both parent and child admin caps
- Child org retains all its agents/tasks after detachment

```
RootOrg (depth=0)
├── Engineering (depth=1)
│   ├── Frontend (depth=2)
│   └── Backend (depth=2)
│       └── Database (depth=3)
└── Research (depth=1)
    └── AI-Safety (depth=2)
```

## Event Flow

Every state change emits an event for off-chain indexing:

```
OrgCreated           → org created
OrgDeactivated       → org deactivated
OrgDescriptionUpdated → description changed
OrgAdminTransferred  → admin ownership transferred
AgentRegistered      → agent joined org
AgentDeactivated     → agent self-deactivated
AgentRemoved         → agent removed by admin
AgentCapabilityUpdated → capability tags changed
TaskCreated          → task created
TaskAssigned         → task assigned to agent
TaskSubmitted        → work submitted
TaskVerified         → submission verified
TaskCompleted        → task completed
TaskRejected         → submission rejected
SubOrgCreated        → child org created
SubOrgDetached       → child org detached from parent
```

## Design Patterns

1. **Capability pattern** — `OrgAdminCap has key, store`, passed by reference for authorization
2. **Registry pattern** — Shared singleton with `Table<K,V>` for global state
3. **Event pattern** — All events have `has copy, drop`, emitted on every state change
4. **Error pattern** — Private constants + public accessor functions (DeepBookV3 style)
5. **OTW pattern** — One-Time Witness for init in `bootstrap.move`
6. **Shared vs Owned** — Organizations and Tasks are shared (multi-party access); AdminCap and AgentCertificate are owned (single-party authority)

## Deployment

```bash
# Build
sui move build --silence-warnings

# Test
sui move test --gas-limit 100000000

# Deploy to testnet
./scripts/deploy.sh testnet
```

The `bootstrap.move` module's `init` function runs automatically on publish, creating the shared `ProtocolRegistry`.
