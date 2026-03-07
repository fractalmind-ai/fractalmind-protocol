/// FractalMind Protocol — Organization
/// ProtocolRegistry (shared singleton), Organization (shared), OrgAdminCap (owned).
module fractalmind_protocol::organization {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::String;
    use std::option::{Self, Option};

    use fractalmind_protocol::constants;

    // ===== Friends =====

    /* fractal module needs to mutate Organization fields */

    // ===== Structs =====

    /// Global singleton — tracks every organization.
    public struct ProtocolRegistry has key {
        id: UID,
        /// org_id → exists
        organizations: Table<ID, bool>,
        /// name → org_id (uniqueness)
        name_registry: Table<String, ID>,
        /// total orgs ever created
        org_count: u64,
    }

    /// A fractal organization. Shared object.
    public struct Organization has key {
        id: UID,
        name: String,
        description: String,
        admin: address,
        is_active: bool,
        /// agent_address → exists
        agents: Table<address, bool>,
        agent_count: u64,
        /// task_id → exists
        tasks: Table<ID, bool>,
        task_count: u64,
        /// parent org id (None for root)
        parent_org: Option<ID>,
        /// child_org_id → exists
        child_orgs: Table<ID, bool>,
        child_org_count: u64,
        /// nesting depth (0 = root)
        depth: u64,
        /// true after a governance object is created for this org
        governance_created: bool,
        created_at: u64,
    }

    /// Admin capability for a specific organization. Owned object.
    public struct OrgAdminCap has key, store {
        id: UID,
        org_id: ID,
    }

    // ===== Events =====

    public struct OrgCreated has copy, drop {
        org_id: ID,
        name: String,
        admin: address,
        depth: u64,
        parent_org: Option<ID>,
    }

    public struct OrgDeactivated has copy, drop {
        org_id: ID,
        admin: address,
    }

    public struct OrgDescriptionUpdated has copy, drop {
        org_id: ID,
        new_description: String,
    }

    public struct OrgAdminTransferred has copy, drop {
        org_id: ID,
        old_admin: address,
        new_admin: address,
    }

    // ===== Init (called from bootstrap) =====

    /// Create and share the global ProtocolRegistry. Called once at publish.
    public(package) fun create_and_share_registry(ctx: &mut TxContext) {
        let registry = ProtocolRegistry {
            id: object::new(ctx),
            organizations: table::new(ctx),
            name_registry: table::new(ctx),
            org_count: 0,
        };
        transfer::share_object(registry);
    }

    // ===== Public Functions =====

    /// Permissionless: anyone can create an organization.
    #[allow(lint(self_transfer))]
    public fun create_organization(
        registry: &mut ProtocolRegistry,
        name: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let created_at = tx_context::epoch_timestamp_ms(ctx);

        assert!(std::string::length(&name) > 0, constants::e_empty_name());
        assert!(
            !table::contains(&registry.name_registry, name),
            constants::e_org_name_taken(),
        );

        let org = Organization {
            id: object::new(ctx),
            name,
            description,
            admin: sender,
            is_active: true,
            agents: table::new(ctx),
            agent_count: 0,
            tasks: table::new(ctx),
            task_count: 0,
            parent_org: option::none(),
            child_orgs: table::new(ctx),
            child_org_count: 0,
            depth: 0,
            governance_created: false,
            created_at,
        };
        let org_id = object::id(&org);

        // Register in global registry
        table::add(&mut registry.organizations, org_id, true);
        table::add(&mut registry.name_registry, name, org_id);
        registry.org_count = registry.org_count + 1;

        // Create admin cap
        let admin_cap = OrgAdminCap {
            id: object::new(ctx),
            org_id,
        };

        event::emit(OrgCreated {
            org_id,
            name,
            admin: sender,
            depth: 0,
            parent_org: option::none(),
        });

        transfer::share_object(org);
        transfer::transfer(admin_cap, sender);
    }

    /// Admin-only: deactivate an organization.
    public fun deactivate_organization(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        ctx: &TxContext,
    ) {
        assert!(admin_cap.org_id == object::id(org), constants::e_not_admin());
        assert!(org.is_active, constants::e_org_already_deactivated());

        org.is_active = false;

        event::emit(OrgDeactivated {
            org_id: object::id(org),
            admin: tx_context::sender(ctx),
        });
    }

    /// Admin-only: update description.
    public fun update_description(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        new_description: String,
    ) {
        assert!(admin_cap.org_id == object::id(org), constants::e_not_admin());
        assert!(org.is_active, constants::e_org_not_active());

        org.description = new_description;

        event::emit(OrgDescriptionUpdated {
            org_id: object::id(org),
            new_description,
        });
    }

    /// Admin-only: transfer admin to new address. Consumes old cap, creates new one.
    #[allow(lint(self_transfer))]
    public fun transfer_admin(
        admin_cap: OrgAdminCap,
        org: &mut Organization,
        new_admin: address,
        ctx: &mut TxContext,
    ) {
        let org_id = object::id(org);
        assert!(admin_cap.org_id == org_id, constants::e_not_admin());
        assert!(org.is_active, constants::e_org_not_active());

        let old_admin = org.admin;
        org.admin = new_admin;

        // Destroy old cap
        let OrgAdminCap { id, org_id: _ } = admin_cap;
        object::delete(id);

        // Create new cap for new admin
        let new_cap = OrgAdminCap {
            id: object::new(ctx),
            org_id,
        };
        transfer::transfer(new_cap, new_admin);

        event::emit(OrgAdminTransferred {
            org_id,
            old_admin,
            new_admin,
        });
    }

    // ===== Package-visible Mutators (for agent, task, fractal modules) =====

    public(package) fun add_agent(org: &mut Organization, agent: address) {
        table::add(&mut org.agents, agent, true);
        org.agent_count = org.agent_count + 1;
    }

    public(package) fun remove_agent_from_org(org: &mut Organization, agent: address) {
        table::remove(&mut org.agents, agent);
        org.agent_count = org.agent_count - 1;
    }

    public(package) fun add_task(org: &mut Organization, task_id: ID) {
        table::add(&mut org.tasks, task_id, true);
        org.task_count = org.task_count + 1;
    }

    public(package) fun add_child_org(org: &mut Organization, child_id: ID) {
        table::add(&mut org.child_orgs, child_id, true);
        org.child_org_count = org.child_org_count + 1;
    }

    public(package) fun remove_child_org(org: &mut Organization, child_id: ID) {
        table::remove(&mut org.child_orgs, child_id);
        org.child_org_count = org.child_org_count - 1;
    }

    public(package) fun clear_parent(org: &mut Organization) {
        org.parent_org = option::none();
    }

    public(package) fun mark_governance_created(org: &mut Organization) {
        org.governance_created = true;
    }

    /// Create a sub-organization (called from fractal module).
    #[allow(lint(self_transfer))]
    public(package) fun create_sub_organization(
        registry: &mut ProtocolRegistry,
        parent_id: ID,
        parent_depth: u64,
        name: String,
        description: String,
        admin: address,
        ctx: &mut TxContext,
    ): (ID, OrgAdminCap) {
        let created_at = tx_context::epoch_timestamp_ms(ctx);
        let depth = parent_depth + 1;

        assert!(std::string::length(&name) > 0, constants::e_empty_name());
        assert!(
            !table::contains(&registry.name_registry, name),
            constants::e_org_name_taken(),
        );

        let org = Organization {
            id: object::new(ctx),
            name,
            description,
            admin,
            is_active: true,
            agents: table::new(ctx),
            agent_count: 0,
            tasks: table::new(ctx),
            task_count: 0,
            parent_org: option::some(parent_id),
            child_orgs: table::new(ctx),
            child_org_count: 0,
            depth,
            governance_created: false,
            created_at,
        };
        let org_id = object::id(&org);

        table::add(&mut registry.organizations, org_id, true);
        table::add(&mut registry.name_registry, name, org_id);
        registry.org_count = registry.org_count + 1;

        let admin_cap = OrgAdminCap {
            id: object::new(ctx),
            org_id,
        };

        event::emit(OrgCreated {
            org_id,
            name,
            admin,
            depth,
            parent_org: option::some(parent_id),
        });

        transfer::share_object(org);

        (org_id, admin_cap)
    }

    // ===== Query Functions =====

    public fun org_id(org: &Organization): ID { object::id(org) }
    public fun name(org: &Organization): String { org.name }
    public fun description(org: &Organization): String { org.description }
    public fun admin(org: &Organization): address { org.admin }
    public fun is_active(org: &Organization): bool { org.is_active }
    public fun agent_count(org: &Organization): u64 { org.agent_count }
    public fun task_count(org: &Organization): u64 { org.task_count }
    public fun depth(org: &Organization): u64 { org.depth }
    public fun parent_org(org: &Organization): Option<ID> { org.parent_org }
    public fun child_org_count(org: &Organization): u64 { org.child_org_count }
    public fun governance_created(org: &Organization): bool { org.governance_created }
    public fun has_agent(org: &Organization, agent: address): bool {
        table::contains(&org.agents, agent)
    }
    public fun has_task(org: &Organization, task_id: ID): bool {
        table::contains(&org.tasks, task_id)
    }
    public fun has_child_org(org: &Organization, child_id: ID): bool {
        table::contains(&org.child_orgs, child_id)
    }

    public fun registry_org_count(registry: &ProtocolRegistry): u64 { registry.org_count }
    public fun registry_has_org(registry: &ProtocolRegistry, org_id: ID): bool {
        table::contains(&registry.organizations, org_id)
    }

    public fun admin_cap_org_id(cap: &OrgAdminCap): ID { cap.org_id }

    // ===== Test Helpers =====

    #[test_only]
    public fun create_test_registry(ctx: &mut TxContext): ProtocolRegistry {
        ProtocolRegistry {
            id: object::new(ctx),
            organizations: table::new(ctx),
            name_registry: table::new(ctx),
            org_count: 0,
        }
    }

    #[test_only]
    public fun destroy_test_registry(registry: ProtocolRegistry) {
        let ProtocolRegistry { id, organizations, name_registry, org_count: _ } = registry;
        table::drop(organizations);
        table::drop(name_registry);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_test_admin_cap(cap: OrgAdminCap) {
        let OrgAdminCap { id, org_id: _ } = cap;
        object::delete(id);
    }
}
