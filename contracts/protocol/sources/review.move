/// FractalMind Protocol — Review
/// On-chain quality gate with N/M reviewer approvals and reputation impact.
module fractalmind_protocol::review {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use std::option::{Self, Option};
    use std::vector;

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{Self, OrgAdminCap};
    use fractalmind_protocol::task::{Self, Task};
    use fractalmind_protocol::agent::{Self, AgentCertificate};

    // ===== Structs =====

    public struct Review has key {
        id: UID,
        org_id: ID,
        task_id: ID,
        assignee: address,
        reviewers: vector<address>,
        required_approvals: u64,
        reviewer_count: u64,
        decisions: Table<address, u8>,
        votes_cast: u64,
        approval_count: u64,
        rejection_count: u64,
        status: u8,
        created_at: u64,
        finalized_at: Option<u64>,
    }

    // ===== Events =====

    public struct ReviewCreated has copy, drop {
        review_id: ID,
        org_id: ID,
        task_id: ID,
        assignee: address,
        reviewer_count: u64,
        required_approvals: u64,
    }

    public struct ReviewVoted has copy, drop {
        review_id: ID,
        reviewer: address,
        decision: u8,
    }

    public struct ReviewFinalized has copy, drop {
        review_id: ID,
        status: u8,
        approval_count: u64,
        rejection_count: u64,
        reputation_delta: u64,
    }

    // ===== Public Functions =====

    #[allow(lint(self_transfer))]
    public fun create_review(
        admin_cap: &OrgAdminCap,
        task: &Task,
        reviewers: vector<address>,
        required_approvals: u64,
        ctx: &mut TxContext,
    ) {
        let reviewer_count = vector::length(&reviewers);
        let assignee_opt = task::task_assignee(task);
        assert!(option::is_some(&assignee_opt), constants::e_review_agent_cert_mismatch());
        let assignee = *option::borrow(&assignee_opt);

        assert!(
            organization::admin_cap_org_id(admin_cap) == task::task_org_id(task),
            constants::e_not_admin(),
        );
        assert!(
            task::task_status(task) == constants::task_status_completed(),
            constants::e_review_invalid_transition(),
        );
        assert!(reviewer_count > 0, constants::e_review_empty_reviewers());
        assert!(
            required_approvals > 0 && required_approvals <= reviewer_count,
            constants::e_review_invalid_threshold(),
        );

        // Validate reviewer set at creation time: no self-review and no duplicates.
        let mut unique_reviewers = vector::empty();
        let mut i = 0;
        while (i < reviewer_count) {
            let reviewer = *vector::borrow(&reviewers, i);
            assert!(reviewer != assignee, constants::e_review_not_reviewer());
            assert!(
                !vector::contains(&unique_reviewers, &reviewer),
                constants::e_review_already_reviewed(),
            );
            vector::push_back(&mut unique_reviewers, reviewer);
            i = i + 1;
        };

        let review = Review {
            id: object::new(ctx),
            org_id: task::task_org_id(task),
            task_id: object::id(task),
            assignee,
            reviewers,
            required_approvals,
            reviewer_count,
            decisions: table::new(ctx),
            votes_cast: 0,
            approval_count: 0,
            rejection_count: 0,
            status: constants::review_status_voting(),
            created_at: tx_context::epoch_timestamp_ms(ctx),
            finalized_at: option::none(),
        };

        event::emit(ReviewCreated {
            review_id: object::id(&review),
            org_id: review.org_id,
            task_id: review.task_id,
            assignee: review.assignee,
            reviewer_count,
            required_approvals,
        });

        transfer::share_object(review);
    }

    public fun submit_review(
        review: &mut Review,
        reviewer_cert: &AgentCertificate,
        decision: u8,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(review.status == constants::review_status_voting(), constants::e_review_invalid_transition());
        assert!(agent::cert_org_id(reviewer_cert) == review.org_id, constants::e_unauthorized());
        assert!(agent::cert_agent(reviewer_cert) == sender, constants::e_unauthorized());
        assert!(agent::cert_status(reviewer_cert) == constants::agent_status_active(), constants::e_agent_not_active());
        assert!(vector::contains(&review.reviewers, &sender), constants::e_review_not_reviewer());
        assert!(!table::contains(&review.decisions, sender), constants::e_review_already_reviewed());
        assert!(
            decision == constants::review_decision_approve() ||
            decision == constants::review_decision_reject(),
            constants::e_review_invalid_decision(),
        );

        table::add(&mut review.decisions, sender, decision);
        review.votes_cast = review.votes_cast + 1;

        if (decision == constants::review_decision_approve()) {
            review.approval_count = review.approval_count + 1;
        } else {
            review.rejection_count = review.rejection_count + 1;
        };

        event::emit(ReviewVoted {
            review_id: object::id(review),
            reviewer: sender,
            decision,
        });
    }

    public fun finalize_review(
        admin_cap: &OrgAdminCap,
        review: &mut Review,
        assignee_cert: &mut AgentCertificate,
        ctx: &TxContext,
    ) {
        assert!(organization::admin_cap_org_id(admin_cap) == review.org_id, constants::e_not_admin());
        assert!(review.status == constants::review_status_voting(), constants::e_review_invalid_transition());
        assert!(agent::cert_org_id(assignee_cert) == review.org_id, constants::e_review_agent_cert_mismatch());
        assert!(agent::cert_agent(assignee_cert) == review.assignee, constants::e_review_agent_cert_mismatch());

        let pass = review.approval_count >= review.required_approvals;
        let fail_early = review.rejection_count > (review.reviewer_count - review.required_approvals);
        let all_votes_in = review.votes_cast == review.reviewer_count;
        assert!(pass || fail_early || all_votes_in, constants::e_review_invalid_transition());

        let reputation_delta = 1;
        if (pass) {
            review.status = constants::review_status_passed();
            agent::increase_reputation(assignee_cert, reputation_delta);
        } else {
            review.status = constants::review_status_rejected();
            agent::decrease_reputation(assignee_cert, reputation_delta);
        };
        review.finalized_at = option::some(tx_context::epoch_timestamp_ms(ctx));

        event::emit(ReviewFinalized {
            review_id: object::id(review),
            status: review.status,
            approval_count: review.approval_count,
            rejection_count: review.rejection_count,
            reputation_delta,
        });
    }

    // ===== Query Functions =====

    public fun review_id(review: &Review): ID { object::id(review) }
    public fun review_org_id(review: &Review): ID { review.org_id }
    public fun review_task_id(review: &Review): ID { review.task_id }
    public fun review_assignee(review: &Review): address { review.assignee }
    public fun review_status(review: &Review): u8 { review.status }
    public fun review_votes_cast(review: &Review): u64 { review.votes_cast }
    public fun review_approval_count(review: &Review): u64 { review.approval_count }
    public fun review_rejection_count(review: &Review): u64 { review.rejection_count }
    public fun review_required_approvals(review: &Review): u64 { review.required_approvals }
    public fun review_reviewer_count(review: &Review): u64 { review.reviewer_count }
}
