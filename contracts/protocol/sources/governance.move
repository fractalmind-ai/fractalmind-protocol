/// FractalMind Protocol — Governance
/// Organization-level DAO proposals and weighted voting.
module fractalmind_protocol::governance {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::String;
    use std::option::{Self, Option};
    use std::vector;

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};

    // ===== Structs =====

    /// Shared governance configuration for one organization.
    public struct Governance has key {
        id: UID,
        org_id: ID,
        proposal_count: u64,
    }

    /// Proposal object with explicit state machine:
    /// Created -> Voting -> Passed/Rejected -> Executed.
    public struct Proposal has key {
        id: UID,
        governance_id: ID,
        org_id: ID,
        creator: address,
        title: String,
        description: String,
        voting_deadline: u64,
        execution_payload: vector<u8>,
        status: u8,
        for_votes: u64,
        against_votes: u64,
        abstain_votes: u64,
        has_voted: Table<address, bool>,
        created_at: u64,
        voting_started_at: Option<u64>,
        finalized_at: Option<u64>,
        executed_at: Option<u64>,
    }

    // ===== Events =====

    public struct GovernanceCreated has copy, drop {
        governance_id: ID,
        org_id: ID,
        admin: address,
    }

    public struct ProposalCreated has copy, drop {
        proposal_id: ID,
        governance_id: ID,
        org_id: ID,
        creator: address,
        voting_deadline: u64,
    }

    public struct ProposalVotingStarted has copy, drop {
        proposal_id: ID,
        governance_id: ID,
        started_by: address,
    }

    public struct ProposalVoted has copy, drop {
        proposal_id: ID,
        voter: address,
        vote: u8,
        weight: u64,
    }

    public struct ProposalFinalized has copy, drop {
        proposal_id: ID,
        status: u8,
        for_votes: u64,
        against_votes: u64,
        abstain_votes: u64,
    }

    public struct ProposalVotingClosed has copy, drop {
        proposal_id: ID,
        closed_by: address,
        closed_at: u64,
    }

    public struct ProposalExecuted has copy, drop {
        proposal_id: ID,
        executed_by: address,
    }

    // ===== Public Functions =====

    #[allow(lint(self_transfer))]
    public fun create_governance(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        ctx: &mut TxContext,
    ) {
        assert!(
            organization::admin_cap_org_id(admin_cap) == organization::org_id(org),
            constants::e_not_admin(),
        );
        assert!(organization::is_active(org), constants::e_org_not_active());
        assert!(!organization::governance_created(org), constants::e_gov_already_exists());

        let governance = Governance {
            id: object::new(ctx),
            org_id: organization::org_id(org),
            proposal_count: 0,
        };

        event::emit(GovernanceCreated {
            governance_id: object::id(&governance),
            org_id: organization::org_id(org),
            admin: tx_context::sender(ctx),
        });

        organization::mark_governance_created(org);
        transfer::share_object(governance);
    }

    #[allow(lint(self_transfer))]
    public fun create_proposal(
        governance: &mut Governance,
        org: &Organization,
        proposer_cert: &AgentCertificate,
        title: String,
        description: String,
        voting_deadline: u64,
        execution_payload: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let now = tx_context::epoch_timestamp_ms(ctx);
        let sender = tx_context::sender(ctx);

        assert!(organization::is_active(org), constants::e_org_not_active());
        assert!(std::string::length(&title) > 0, constants::e_gov_empty_proposal_title());
        assert!(voting_deadline > now, constants::e_gov_voting_closed());
        assert!(governance.org_id == organization::org_id(org), constants::e_unauthorized());
        assert!(agent::cert_org_id(proposer_cert) == governance.org_id, constants::e_unauthorized());
        assert!(agent::cert_agent(proposer_cert) == sender, constants::e_unauthorized());
        assert!(
            agent::cert_status(proposer_cert) == constants::agent_status_active(),
            constants::e_agent_not_active(),
        );

        let proposal = Proposal {
            id: object::new(ctx),
            governance_id: object::id(governance),
            org_id: governance.org_id,
            creator: sender,
            title,
            description,
            voting_deadline,
            execution_payload,
            status: constants::proposal_status_created(),
            for_votes: 0,
            against_votes: 0,
            abstain_votes: 0,
            has_voted: table::new(ctx),
            created_at: now,
            voting_started_at: option::none(),
            finalized_at: option::none(),
            executed_at: option::none(),
        };
        let proposal_id = object::id(&proposal);
        governance.proposal_count = governance.proposal_count + 1;

        event::emit(ProposalCreated {
            proposal_id,
            governance_id: object::id(governance),
            org_id: governance.org_id,
            creator: sender,
            voting_deadline,
        });

        transfer::share_object(proposal);
    }

    public fun start_voting(
        admin_cap: &OrgAdminCap,
        governance: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        assert!(organization::admin_cap_org_id(admin_cap) == governance.org_id, constants::e_not_admin());
        assert!(proposal.governance_id == object::id(governance), constants::e_unauthorized());
        assert!(proposal.status == constants::proposal_status_created(), constants::e_gov_invalid_transition());

        proposal.status = constants::proposal_status_voting();
        proposal.voting_started_at = option::some(tx_context::epoch_timestamp_ms(ctx));

        event::emit(ProposalVotingStarted {
            proposal_id: object::id(proposal),
            governance_id: proposal.governance_id,
            started_by: tx_context::sender(ctx),
        });
    }

    public fun cast_vote(
        proposal: &mut Proposal,
        voter_cert: &AgentCertificate,
        vote: u8,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch_timestamp_ms(ctx);

        assert!(proposal.status == constants::proposal_status_voting(), constants::e_gov_invalid_transition());
        assert!(now <= proposal.voting_deadline, constants::e_gov_voting_closed());
        assert!(agent::cert_org_id(voter_cert) == proposal.org_id, constants::e_unauthorized());
        assert!(agent::cert_agent(voter_cert) == sender, constants::e_unauthorized());
        assert!(agent::cert_status(voter_cert) == constants::agent_status_active(), constants::e_agent_not_active());
        assert!(!table::contains(&proposal.has_voted, sender), constants::e_gov_already_voted());
        assert!(
            vote == constants::vote_for() ||
            vote == constants::vote_against() ||
            vote == constants::vote_abstain(),
            constants::e_gov_invalid_vote(),
        );

        let weight = agent::cert_voting_power(voter_cert);
        table::add(&mut proposal.has_voted, sender, true);

        if (vote == constants::vote_for()) {
            proposal.for_votes = proposal.for_votes + weight;
        } else if (vote == constants::vote_against()) {
            proposal.against_votes = proposal.against_votes + weight;
        } else {
            proposal.abstain_votes = proposal.abstain_votes + weight;
        };

        event::emit(ProposalVoted {
            proposal_id: object::id(proposal),
            voter: sender,
            vote,
            weight,
        });
    }

    public fun finalize_voting(
        admin_cap: &OrgAdminCap,
        governance: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        let now = tx_context::epoch_timestamp_ms(ctx);

        assert!(organization::admin_cap_org_id(admin_cap) == governance.org_id, constants::e_not_admin());
        assert!(proposal.governance_id == object::id(governance), constants::e_unauthorized());
        assert!(proposal.status == constants::proposal_status_voting(), constants::e_gov_invalid_transition());
        assert!(now >= proposal.voting_deadline, constants::e_gov_voting_not_ended());

        if (proposal.for_votes > proposal.against_votes) {
            proposal.status = constants::proposal_status_passed();
        } else {
            proposal.status = constants::proposal_status_rejected();
        };
        proposal.finalized_at = option::some(now);

        event::emit(ProposalFinalized {
            proposal_id: object::id(proposal),
            status: proposal.status,
            for_votes: proposal.for_votes,
            against_votes: proposal.against_votes,
            abstain_votes: proposal.abstain_votes,
        });
    }

    /// Admin may close voting early in operational emergencies.
    /// This sets deadline to current timestamp; finalization still follows normal logic.
    public fun close_voting(
        admin_cap: &OrgAdminCap,
        governance: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        let now = tx_context::epoch_timestamp_ms(ctx);

        assert!(organization::admin_cap_org_id(admin_cap) == governance.org_id, constants::e_not_admin());
        assert!(proposal.governance_id == object::id(governance), constants::e_unauthorized());
        assert!(proposal.status == constants::proposal_status_voting(), constants::e_gov_invalid_transition());

        proposal.voting_deadline = now;

        event::emit(ProposalVotingClosed {
            proposal_id: object::id(proposal),
            closed_by: tx_context::sender(ctx),
            closed_at: now,
        });
    }

    /// Execution payload is recorded on-chain; the concrete side effects should be
    /// interpreted by an off-chain/governance executor according to protocol rules.
    public fun execute_proposal(
        admin_cap: &OrgAdminCap,
        governance: &Governance,
        proposal: &mut Proposal,
        ctx: &TxContext,
    ) {
        assert!(organization::admin_cap_org_id(admin_cap) == governance.org_id, constants::e_not_admin());
        assert!(proposal.governance_id == object::id(governance), constants::e_unauthorized());
        assert!(proposal.status == constants::proposal_status_passed(), constants::e_gov_invalid_transition());

        proposal.status = constants::proposal_status_executed();
        proposal.executed_at = option::some(tx_context::epoch_timestamp_ms(ctx));

        event::emit(ProposalExecuted {
            proposal_id: object::id(proposal),
            executed_by: tx_context::sender(ctx),
        });
    }

    // ===== Query Functions =====

    public fun governance_org_id(gov: &Governance): ID { gov.org_id }
    public fun governance_id(gov: &Governance): ID { object::id(gov) }
    public fun governance_proposal_count(gov: &Governance): u64 { gov.proposal_count }

    public fun proposal_id(proposal: &Proposal): ID { object::id(proposal) }
    public fun proposal_governance_id(proposal: &Proposal): ID { proposal.governance_id }
    public fun proposal_org_id(proposal: &Proposal): ID { proposal.org_id }
    public fun proposal_creator(proposal: &Proposal): address { proposal.creator }
    public fun proposal_title(proposal: &Proposal): String { proposal.title }
    public fun proposal_description(proposal: &Proposal): String { proposal.description }
    public fun proposal_status(proposal: &Proposal): u8 { proposal.status }
    public fun proposal_voting_deadline(proposal: &Proposal): u64 { proposal.voting_deadline }
    public fun proposal_execution_payload(proposal: &Proposal): vector<u8> { proposal.execution_payload }
    public fun proposal_for_votes(proposal: &Proposal): u64 { proposal.for_votes }
    public fun proposal_against_votes(proposal: &Proposal): u64 { proposal.against_votes }
    public fun proposal_abstain_votes(proposal: &Proposal): u64 { proposal.abstain_votes }
}
