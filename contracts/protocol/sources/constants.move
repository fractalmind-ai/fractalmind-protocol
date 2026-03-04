/// FractalMind Protocol — Constants
/// Error codes, system limits, and status constants.
/// Pattern: private const + public accessor (DeepBookV3 / Destiny style).
module fractalmind_protocol::constants {

    // ===== Error Codes =====

    // System errors (1xxx)
    const E_NOT_IMPLEMENTED: u64 = 1000;
    const E_INVALID_STATE: u64 = 1001;
    const E_ALREADY_INITIALIZED: u64 = 1002;

    // Authorization errors (2xxx)
    const E_UNAUTHORIZED: u64 = 2001;
    const E_NOT_ADMIN: u64 = 2002;
    const E_NOT_MEMBER: u64 = 2003;

    // Organization errors (3xxx)
    const E_ORG_NOT_ACTIVE: u64 = 3001;
    const E_ORG_NAME_TAKEN: u64 = 3002;
    const E_ORG_ALREADY_DEACTIVATED: u64 = 3003;
    const E_MAX_DEPTH_EXCEEDED: u64 = 3004;
    const E_ORG_HAS_PARENT: u64 = 3005;
    const E_ORG_NOT_CHILD: u64 = 3006;
    const E_EMPTY_NAME: u64 = 3007;

    // Agent errors (4xxx)
    const E_AGENT_ALREADY_REGISTERED: u64 = 4001;
    const E_AGENT_NOT_ACTIVE: u64 = 4002;
    const E_AGENT_NOT_FOUND: u64 = 4003;
    const E_TOO_MANY_CAPABILITY_TAGS: u64 = 4004;

    // Task errors (5xxx)
    const E_TASK_INVALID_TRANSITION: u64 = 5001;
    const E_TASK_NOT_ASSIGNEE: u64 = 5002;
    const E_TASK_ALREADY_ASSIGNED: u64 = 5003;
    const E_TASK_NOT_FOUND: u64 = 5004;
    const E_TASK_EMPTY_TITLE: u64 = 5005;

    // ===== System Limits =====

    const MAX_FRACTAL_DEPTH: u64 = 8;
    const MAX_CAPABILITY_TAGS: u64 = 10;

    // ===== Agent Status =====

    const AGENT_STATUS_ACTIVE: u8 = 0;
    const AGENT_STATUS_INACTIVE: u8 = 1;
    const AGENT_STATUS_SUSPENDED: u8 = 2;

    // ===== Task Status =====

    const TASK_STATUS_CREATED: u8 = 0;
    const TASK_STATUS_ASSIGNED: u8 = 1;
    const TASK_STATUS_SUBMITTED: u8 = 2;
    const TASK_STATUS_VERIFIED: u8 = 3;
    const TASK_STATUS_COMPLETED: u8 = 4;
    const TASK_STATUS_REJECTED: u8 = 5;

    // ===== Public Accessors — Error Codes =====

    public fun e_not_implemented(): u64 { E_NOT_IMPLEMENTED }
    public fun e_invalid_state(): u64 { E_INVALID_STATE }
    public fun e_already_initialized(): u64 { E_ALREADY_INITIALIZED }
    public fun e_unauthorized(): u64 { E_UNAUTHORIZED }
    public fun e_not_admin(): u64 { E_NOT_ADMIN }
    public fun e_not_member(): u64 { E_NOT_MEMBER }
    public fun e_org_not_active(): u64 { E_ORG_NOT_ACTIVE }
    public fun e_org_name_taken(): u64 { E_ORG_NAME_TAKEN }
    public fun e_org_already_deactivated(): u64 { E_ORG_ALREADY_DEACTIVATED }
    public fun e_max_depth_exceeded(): u64 { E_MAX_DEPTH_EXCEEDED }
    public fun e_org_has_parent(): u64 { E_ORG_HAS_PARENT }
    public fun e_org_not_child(): u64 { E_ORG_NOT_CHILD }
    public fun e_empty_name(): u64 { E_EMPTY_NAME }
    public fun e_agent_already_registered(): u64 { E_AGENT_ALREADY_REGISTERED }
    public fun e_agent_not_active(): u64 { E_AGENT_NOT_ACTIVE }
    public fun e_agent_not_found(): u64 { E_AGENT_NOT_FOUND }
    public fun e_too_many_capability_tags(): u64 { E_TOO_MANY_CAPABILITY_TAGS }
    public fun e_task_invalid_transition(): u64 { E_TASK_INVALID_TRANSITION }
    public fun e_task_not_assignee(): u64 { E_TASK_NOT_ASSIGNEE }
    public fun e_task_already_assigned(): u64 { E_TASK_ALREADY_ASSIGNED }
    public fun e_task_not_found(): u64 { E_TASK_NOT_FOUND }
    public fun e_task_empty_title(): u64 { E_TASK_EMPTY_TITLE }

    // ===== Public Accessors — Limits =====

    public fun max_fractal_depth(): u64 { MAX_FRACTAL_DEPTH }
    public fun max_capability_tags(): u64 { MAX_CAPABILITY_TAGS }

    // ===== Public Accessors — Agent Status =====

    public fun agent_status_active(): u8 { AGENT_STATUS_ACTIVE }
    public fun agent_status_inactive(): u8 { AGENT_STATUS_INACTIVE }
    public fun agent_status_suspended(): u8 { AGENT_STATUS_SUSPENDED }

    // ===== Public Accessors — Task Status =====

    public fun task_status_created(): u8 { TASK_STATUS_CREATED }
    public fun task_status_assigned(): u8 { TASK_STATUS_ASSIGNED }
    public fun task_status_submitted(): u8 { TASK_STATUS_SUBMITTED }
    public fun task_status_verified(): u8 { TASK_STATUS_VERIFIED }
    public fun task_status_completed(): u8 { TASK_STATUS_COMPLETED }
    public fun task_status_rejected(): u8 { TASK_STATUS_REJECTED }
}
