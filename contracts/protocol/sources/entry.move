/// FractalMind Protocol — Entry
/// Thin `entry` wrappers for PTB (Programmable Transaction Block) usage.
#[allow(lint(public_entry))]
module fractalmind_protocol::entry {
    use sui::tx_context::TxContext;
    use std::string::String;

    use fractalmind_protocol::organization::{
        Self, Organization, OrgAdminCap, ProtocolRegistry,
    };
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::task::{Self, Task};
    use fractalmind_protocol::fractal;
    use fractalmind_protocol::governance::{Self, Governance, Proposal};
    use fractalmind_protocol::review::{Self, Review};

    // ===== Organization Entry Points =====

    public entry fun create_organization(
        registry: &mut ProtocolRegistry,
        name: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        organization::create_organization(registry, name, description, ctx);
    }

    public entry fun deactivate_organization(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        organization::deactivate_organization(admin_cap, org, ctx);
    }

    public entry fun update_org_description(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        new_description: String,
    ) {
        organization::update_description(admin_cap, org, new_description);
    }

    public entry fun transfer_org_admin(
        admin_cap: OrgAdminCap,
        org: &mut Organization,
        new_admin: address,
        ctx: &mut TxContext,
    ) {
        organization::transfer_admin(admin_cap, org, new_admin, ctx);
    }

    // ===== Agent Entry Points =====

    public entry fun register_agent(
        org: &mut Organization,
        capability_tags: vector<String>,
        ctx: &mut TxContext,
    ) {
        agent::register_agent(org, capability_tags, ctx);
    }

    public entry fun deactivate_agent(
        cert: &mut AgentCertificate,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        agent::deactivate_agent(cert, org, ctx);
    }

    public entry fun remove_agent(
        admin_cap: &OrgAdminCap,
        cert: &mut AgentCertificate,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        agent::remove_agent(admin_cap, cert, org, ctx);
    }

    public entry fun update_agent_capabilities(
        cert: &mut AgentCertificate,
        new_tags: vector<String>,
        ctx: &TxContext,
    ) {
        agent::update_capabilities(cert, new_tags, ctx);
    }

    // ===== Task Entry Points =====

    public entry fun create_task(
        org: &mut Organization,
        cert: &AgentCertificate,
        title: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        task::create_task(org, cert, title, description, ctx);
    }

    public entry fun assign_task(
        task: &mut Task,
        org: &Organization,
        cert: &AgentCertificate,
        ctx: &mut TxContext,
    ) {
        task::assign_task(task, org, cert, ctx);
    }

    public entry fun submit_task(
        task: &mut Task,
        submission: String,
        ctx: &mut TxContext,
    ) {
        task::submit_task(task, submission, ctx);
    }

    public entry fun verify_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        ctx: &TxContext,
    ) {
        task::verify_task(admin_cap, task, ctx);
    }

    public entry fun complete_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        assignee_cert: &mut AgentCertificate,
        ctx: &mut TxContext,
    ) {
        task::complete_task(admin_cap, task, assignee_cert, ctx);
    }

    public entry fun reject_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        assignee_cert: &mut AgentCertificate,
        reason: String,
        ctx: &TxContext,
    ) {
        task::reject_task(admin_cap, task, assignee_cert, reason, ctx);
    }

    // ===== Fractal Entry Points =====

    public entry fun create_sub_organization(
        admin_cap: &OrgAdminCap,
        registry: &mut ProtocolRegistry,
        parent_org: &mut Organization,
        name: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        fractal::create_sub_organization(admin_cap, registry, parent_org, name, description, ctx);
    }

    public entry fun detach_sub_organization(
        parent_admin_cap: &OrgAdminCap,
        child_admin_cap: &OrgAdminCap,
        parent_org: &mut Organization,
        child_org: &mut Organization,
    ) {
        fractal::detach_sub_organization(parent_admin_cap, child_admin_cap, parent_org, child_org);
    }

    // ===== Governance Entry Points =====

    public entry fun create_governance(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        ctx: &mut TxContext,
    ) {
        governance::create_governance(admin_cap, org, ctx);
    }

    public entry fun create_proposal(
        governance_obj: &mut Governance,
        org: &Organization,
        proposer_cert: &AgentCertificate,
        title: String,
        description: String,
        voting_deadline: u64,
        execution_payload: vector<u8>,
        ctx: &mut TxContext,
    ) {
        governance::create_proposal(
            governance_obj,
            org,
            proposer_cert,
            title,
            description,
            voting_deadline,
            execution_payload,
            ctx,
        );
    }

    public entry fun start_proposal_voting(
        admin_cap: &OrgAdminCap,
        governance_obj: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        governance::start_voting(admin_cap, governance_obj, proposal, ctx);
    }

    public entry fun cast_proposal_vote(
        proposal: &mut Proposal,
        voter_cert: &AgentCertificate,
        vote: u8,
        ctx: &TxContext,
    ) {
        governance::cast_vote(proposal, voter_cert, vote, ctx);
    }

    public entry fun finalize_proposal_voting(
        admin_cap: &OrgAdminCap,
        governance_obj: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        governance::finalize_voting(admin_cap, governance_obj, proposal, ctx);
    }

    public entry fun close_proposal_voting(
        admin_cap: &OrgAdminCap,
        governance_obj: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        governance::close_voting(admin_cap, governance_obj, proposal, ctx);
    }

    public entry fun execute_proposal(
        admin_cap: &OrgAdminCap,
        governance_obj: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        governance::execute_proposal(admin_cap, governance_obj, proposal, ctx);
    }

    // ===== Review Entry Points =====

    public entry fun create_review(
        admin_cap: &OrgAdminCap,
        task: &Task,
        reviewers: vector<address>,
        required_approvals: u64,
        ctx: &mut TxContext,
    ) {
        review::create_review(admin_cap, task, reviewers, required_approvals, ctx);
    }

    public entry fun submit_review(
        review_obj: &mut Review,
        reviewer_cert: &AgentCertificate,
        decision: u8,
        ctx: &TxContext,
    ) {
        review::submit_review(review_obj, reviewer_cert, decision, ctx);
    }

    public entry fun finalize_review(
        admin_cap: &OrgAdminCap,
        review_obj: &mut Review,
        assignee_cert: &mut AgentCertificate,
        ctx: &TxContext,
    ) {
        review::finalize_review(admin_cap, review_obj, assignee_cert, ctx);
    }
}
