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

    // Governance errors (6xxx)
    const E_GOV_INVALID_TRANSITION: u64 = 6001;
    const E_GOV_INVALID_VOTE: u64 = 6002;
    const E_GOV_ALREADY_VOTED: u64 = 6003;
    const E_GOV_VOTING_CLOSED: u64 = 6004;
    const E_GOV_VOTING_NOT_ENDED: u64 = 6005;
    const E_GOV_EMPTY_PROPOSAL_TITLE: u64 = 6006;
    const E_GOV_ALREADY_EXISTS: u64 = 6007;

    // Review errors (7xxx)
    const E_REVIEW_INVALID_TRANSITION: u64 = 7001;
    const E_REVIEW_INVALID_DECISION: u64 = 7002;
    const E_REVIEW_ALREADY_REVIEWED: u64 = 7003;
    const E_REVIEW_NOT_REVIEWER: u64 = 7004;
    const E_REVIEW_INVALID_THRESHOLD: u64 = 7005;
    const E_REVIEW_EMPTY_REVIEWERS: u64 = 7006;
    const E_REVIEW_AGENT_CERT_MISMATCH: u64 = 7007;

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

    // ===== Governance Proposal Status =====

    const PROPOSAL_STATUS_CREATED: u8 = 0;
    const PROPOSAL_STATUS_VOTING: u8 = 1;
    const PROPOSAL_STATUS_PASSED: u8 = 2;
    const PROPOSAL_STATUS_REJECTED: u8 = 3;
    const PROPOSAL_STATUS_EXECUTED: u8 = 4;

    // ===== Governance Vote Option =====

    const VOTE_FOR: u8 = 1;
    const VOTE_AGAINST: u8 = 2;
    const VOTE_ABSTAIN: u8 = 3;

    // ===== Review Status =====

    const REVIEW_STATUS_VOTING: u8 = 0;
    const REVIEW_STATUS_PASSED: u8 = 1;
    const REVIEW_STATUS_REJECTED: u8 = 2;

    // ===== Review Decision =====

    const REVIEW_DECISION_APPROVE: u8 = 1;
    const REVIEW_DECISION_REJECT: u8 = 2;

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
    public fun e_gov_invalid_transition(): u64 { E_GOV_INVALID_TRANSITION }
    public fun e_gov_invalid_vote(): u64 { E_GOV_INVALID_VOTE }
    public fun e_gov_already_voted(): u64 { E_GOV_ALREADY_VOTED }
    public fun e_gov_voting_closed(): u64 { E_GOV_VOTING_CLOSED }
    public fun e_gov_voting_not_ended(): u64 { E_GOV_VOTING_NOT_ENDED }
    public fun e_gov_empty_proposal_title(): u64 { E_GOV_EMPTY_PROPOSAL_TITLE }
    public fun e_gov_already_exists(): u64 { E_GOV_ALREADY_EXISTS }
    public fun e_review_invalid_transition(): u64 { E_REVIEW_INVALID_TRANSITION }
    public fun e_review_invalid_decision(): u64 { E_REVIEW_INVALID_DECISION }
    public fun e_review_already_reviewed(): u64 { E_REVIEW_ALREADY_REVIEWED }
    public fun e_review_not_reviewer(): u64 { E_REVIEW_NOT_REVIEWER }
    public fun e_review_invalid_threshold(): u64 { E_REVIEW_INVALID_THRESHOLD }
    public fun e_review_empty_reviewers(): u64 { E_REVIEW_EMPTY_REVIEWERS }
    public fun e_review_agent_cert_mismatch(): u64 { E_REVIEW_AGENT_CERT_MISMATCH }

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
    public fun proposal_status_created(): u8 { PROPOSAL_STATUS_CREATED }
    public fun proposal_status_voting(): u8 { PROPOSAL_STATUS_VOTING }
    public fun proposal_status_passed(): u8 { PROPOSAL_STATUS_PASSED }
    public fun proposal_status_rejected(): u8 { PROPOSAL_STATUS_REJECTED }
    public fun proposal_status_executed(): u8 { PROPOSAL_STATUS_EXECUTED }
    public fun vote_for(): u8 { VOTE_FOR }
    public fun vote_against(): u8 { VOTE_AGAINST }
    public fun vote_abstain(): u8 { VOTE_ABSTAIN }
    public fun review_status_voting(): u8 { REVIEW_STATUS_VOTING }
    public fun review_status_passed(): u8 { REVIEW_STATUS_PASSED }
    public fun review_status_rejected(): u8 { REVIEW_STATUS_REJECTED }
    public fun review_decision_approve(): u8 { REVIEW_DECISION_APPROVE }
    public fun review_decision_reject(): u8 { REVIEW_DECISION_REJECT }
}
