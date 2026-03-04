/// FractalMind Protocol — Task
/// Task lifecycle state machine: Created → Assigned → Submitted → Verified → Completed
///                                                                        ↘ Rejected → (reassignable)
module fractalmind_protocol::task {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::string::String;
    use std::option::{Self, Option};

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};

    // ===== Structs =====

    /// Task object. Shared so admin + assignee can both mutate.
    public struct Task has key {
        id: UID,
        org_id: ID,
        creator: address,
        title: String,
        description: String,
        status: u8,
        assignee: Option<address>,
        submission: Option<String>,
        verifier: Option<address>,
        created_at: u64,
        assigned_at: Option<u64>,
        submitted_at: Option<u64>,
        completed_at: Option<u64>,
    }

    // ===== Events =====

    public struct TaskCreated has copy, drop {
        task_id: ID,
        org_id: ID,
        creator: address,
        title: String,
    }

    public struct TaskAssigned has copy, drop {
        task_id: ID,
        org_id: ID,
        assignee: address,
    }

    public struct TaskSubmitted has copy, drop {
        task_id: ID,
        org_id: ID,
        assignee: address,
    }

    public struct TaskVerified has copy, drop {
        task_id: ID,
        org_id: ID,
        verifier: address,
    }

    public struct TaskCompleted has copy, drop {
        task_id: ID,
        org_id: ID,
        assignee: address,
        verifier: address,
    }

    public struct TaskRejected has copy, drop {
        task_id: ID,
        org_id: ID,
        verifier: address,
        reason: String,
    }

    // ===== Public Functions =====

    /// Create a task. Caller must be a member (agent) of the org.
    public fun create_task(
        org: &mut Organization,
        cert: &AgentCertificate,
        title: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let org_id = organization::org_id(org);

        assert!(organization::is_active(org), constants::e_org_not_active());
        assert!(agent::cert_org_id(cert) == org_id, constants::e_unauthorized());
        assert!(agent::cert_agent(cert) == sender, constants::e_unauthorized());
        assert!(agent::cert_status(cert) == constants::agent_status_active(), constants::e_agent_not_active());
        assert!(std::string::length(&title) > 0, constants::e_task_empty_title());

        let created_at = tx_context::epoch_timestamp_ms(ctx);

        let task = Task {
            id: object::new(ctx),
            org_id,
            creator: sender,
            title,
            description,
            status: constants::task_status_created(),
            assignee: option::none(),
            submission: option::none(),
            verifier: option::none(),
            created_at,
            assigned_at: option::none(),
            submitted_at: option::none(),
            completed_at: option::none(),
        };
        let task_id = object::id(&task);

        organization::add_task(org, task_id);

        event::emit(TaskCreated {
            task_id,
            org_id,
            creator: sender,
            title,
        });

        transfer::share_object(task);
    }

    /// Assign a task. Admin can assign, or an agent can self-claim.
    public fun assign_task(
        task: &mut Task,
        org: &Organization,
        cert: &AgentCertificate,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let org_id = organization::org_id(org);

        assert!(task.org_id == org_id, constants::e_unauthorized());
        assert!(
            task.status == constants::task_status_created() ||
            task.status == constants::task_status_rejected(),
            constants::e_task_invalid_transition(),
        );

        // Agent self-claims: must be active member
        assert!(agent::cert_org_id(cert) == org_id, constants::e_unauthorized());
        assert!(agent::cert_agent(cert) == sender, constants::e_unauthorized());
        assert!(agent::cert_status(cert) == constants::agent_status_active(), constants::e_agent_not_active());

        task.status = constants::task_status_assigned();
        task.assignee = option::some(sender);
        task.assigned_at = option::some(tx_context::epoch_timestamp_ms(ctx));
        // Clear previous submission/verifier on reassignment
        task.submission = option::none();
        task.verifier = option::none();

        event::emit(TaskAssigned {
            task_id: object::id(task),
            org_id,
            assignee: sender,
        });
    }

    /// Submit work. Assignee only.
    public fun submit_task(
        task: &mut Task,
        submission: String,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(task.status == constants::task_status_assigned(), constants::e_task_invalid_transition());
        assert!(option::contains(&task.assignee, &sender), constants::e_task_not_assignee());

        task.status = constants::task_status_submitted();
        task.submission = option::some(submission);
        task.submitted_at = option::some(tx_context::epoch_timestamp_ms(ctx));

        event::emit(TaskSubmitted {
            task_id: object::id(task),
            org_id: task.org_id,
            assignee: sender,
        });
    }

    /// Verify task submission. Admin only.
    public fun verify_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            organization::admin_cap_org_id(admin_cap) == task.org_id,
            constants::e_not_admin(),
        );
        assert!(task.status == constants::task_status_submitted(), constants::e_task_invalid_transition());

        task.status = constants::task_status_verified();
        task.verifier = option::some(sender);

        event::emit(TaskVerified {
            task_id: object::id(task),
            org_id: task.org_id,
            verifier: sender,
        });
    }

    /// Complete task after verification. Admin only.
    /// Increments the assignee's completed task count.
    public fun complete_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        assignee_cert: &mut AgentCertificate,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            organization::admin_cap_org_id(admin_cap) == task.org_id,
            constants::e_not_admin(),
        );
        assert!(task.status == constants::task_status_verified(), constants::e_task_invalid_transition());

        let assignee = *option::borrow(&task.assignee);
        assert!(agent::cert_agent(assignee_cert) == assignee, constants::e_unauthorized());

        task.status = constants::task_status_completed();
        task.completed_at = option::some(tx_context::epoch_timestamp_ms(ctx));

        agent::increment_completed_tasks(assignee_cert);

        let verifier = *option::borrow(&task.verifier);

        event::emit(TaskCompleted {
            task_id: object::id(task),
            org_id: task.org_id,
            assignee,
            verifier,
        });
    }

    /// Reject task submission. Admin only. Task goes back to rejectable state.
    public fun reject_task(
        admin_cap: &OrgAdminCap,
        task: &mut Task,
        assignee_cert: &mut AgentCertificate,
        reason: String,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            organization::admin_cap_org_id(admin_cap) == task.org_id,
            constants::e_not_admin(),
        );
        assert!(task.status == constants::task_status_submitted(), constants::e_task_invalid_transition());

        let assignee = *option::borrow(&task.assignee);
        assert!(agent::cert_agent(assignee_cert) == assignee, constants::e_unauthorized());

        task.status = constants::task_status_rejected();
        agent::decrease_reputation(assignee_cert, 1);

        event::emit(TaskRejected {
            task_id: object::id(task),
            org_id: task.org_id,
            verifier: sender,
            reason,
        });
    }

    // ===== Query Functions =====

    public fun task_org_id(task: &Task): ID { task.org_id }
    public fun task_creator(task: &Task): address { task.creator }
    public fun task_title(task: &Task): String { task.title }
    public fun task_description(task: &Task): String { task.description }
    public fun task_status(task: &Task): u8 { task.status }
    public fun task_assignee(task: &Task): Option<address> { task.assignee }
    public fun task_submission(task: &Task): Option<String> { task.submission }
    public fun task_verifier(task: &Task): Option<address> { task.verifier }
}
