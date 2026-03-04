/// FractalMind Protocol — Agent
/// AgentCertificate (owned), registration, deactivation, capabilities.
module fractalmind_protocol::agent {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::string::String;
    use std::vector;

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};

    // ===== Structs =====

    /// Proof of agent membership in an organization. Owned by the agent address.
    public struct AgentCertificate has key, store {
        id: UID,
        org_id: ID,
        agent: address,
        capability_tags: vector<String>,
        status: u8,
        tasks_completed: u64,
    }

    // ===== Events =====

    public struct AgentRegistered has copy, drop {
        org_id: ID,
        agent: address,
        cert_id: ID,
    }

    public struct AgentDeactivated has copy, drop {
        org_id: ID,
        agent: address,
    }

    public struct AgentRemoved has copy, drop {
        org_id: ID,
        agent: address,
        removed_by: address,
    }

    public struct AgentCapabilityUpdated has copy, drop {
        org_id: ID,
        agent: address,
        new_tags: vector<String>,
    }

    // ===== Public Functions =====

    /// Permissionless: any address can register as an agent in an active org.
    #[allow(lint(self_transfer))]
    public fun register_agent(
        org: &mut Organization,
        capability_tags: vector<String>,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(organization::is_active(org), constants::e_org_not_active());
        assert!(!organization::has_agent(org, sender), constants::e_agent_already_registered());
        assert!(
            vector::length(&capability_tags) <= constants::max_capability_tags(),
            constants::e_too_many_capability_tags(),
        );

        let cert = AgentCertificate {
            id: object::new(ctx),
            org_id: organization::org_id(org),
            agent: sender,
            capability_tags,
            status: constants::agent_status_active(),
            tasks_completed: 0,
        };
        let cert_id = object::id(&cert);

        organization::add_agent(org, sender);

        event::emit(AgentRegistered {
            org_id: organization::org_id(org),
            agent: sender,
            cert_id,
        });

        transfer::transfer(cert, sender);
    }

    /// Self-deactivate: agent deactivates their own certificate.
    public fun deactivate_agent(
        cert: &mut AgentCertificate,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        assert!(cert.agent == sender, constants::e_unauthorized());
        assert!(cert.status == constants::agent_status_active(), constants::e_agent_not_active());

        cert.status = constants::agent_status_inactive();
        organization::remove_agent_from_org(org, sender);

        event::emit(AgentDeactivated {
            org_id: cert.org_id,
            agent: sender,
        });
    }

    /// Admin-only: remove an agent from the organization.
    public fun remove_agent(
        admin_cap: &OrgAdminCap,
        cert: &mut AgentCertificate,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        assert!(
            organization::admin_cap_org_id(admin_cap) == organization::org_id(org),
            constants::e_not_admin(),
        );
        assert!(cert.org_id == organization::org_id(org), constants::e_unauthorized());
        assert!(cert.status == constants::agent_status_active(), constants::e_agent_not_active());

        cert.status = constants::agent_status_suspended();

        if (organization::has_agent(org, cert.agent)) {
            organization::remove_agent_from_org(org, cert.agent);
        };

        event::emit(AgentRemoved {
            org_id: cert.org_id,
            agent: cert.agent,
            removed_by: tx_context::sender(ctx),
        });
    }

    /// Update capability tags (self or admin).
    public fun update_capabilities(
        cert: &mut AgentCertificate,
        new_tags: vector<String>,
        ctx: &TxContext,
    ) {
        assert!(cert.agent == tx_context::sender(ctx), constants::e_unauthorized());
        assert!(cert.status == constants::agent_status_active(), constants::e_agent_not_active());
        assert!(
            vector::length(&new_tags) <= constants::max_capability_tags(),
            constants::e_too_many_capability_tags(),
        );

        cert.capability_tags = new_tags;

        event::emit(AgentCapabilityUpdated {
            org_id: cert.org_id,
            agent: cert.agent,
            new_tags,
        });
    }

    /// Package-internal: called by task module when a task completes.
    public(package) fun increment_completed_tasks(cert: &mut AgentCertificate) {
        cert.tasks_completed = cert.tasks_completed + 1;
    }

    // ===== Query Functions =====

    public fun cert_org_id(cert: &AgentCertificate): ID { cert.org_id }
    public fun cert_agent(cert: &AgentCertificate): address { cert.agent }
    public fun cert_status(cert: &AgentCertificate): u8 { cert.status }
    public fun cert_tasks_completed(cert: &AgentCertificate): u64 { cert.tasks_completed }
    public fun cert_capability_tags(cert: &AgentCertificate): vector<String> { cert.capability_tags }

    // ===== Test Helpers =====

    #[test_only]
    public fun create_test_cert(
        org_id: ID,
        agent: address,
        ctx: &mut TxContext,
    ): AgentCertificate {
        AgentCertificate {
            id: object::new(ctx),
            org_id,
            agent,
            capability_tags: vector::empty(),
            status: constants::agent_status_active(),
            tasks_completed: 0,
        }
    }

    #[test_only]
    public fun destroy_test_cert(cert: AgentCertificate) {
        let AgentCertificate { id, org_id: _, agent: _, capability_tags: _, status: _, tasks_completed: _ } = cert;
        object::delete(id);
    }
}
