/// FractalMind Protocol — Fractal
/// Sub-organization nesting with depth limit enforcement.
/// No new structs — reuses Organization (parent_org / child_orgs / depth fields).
module fractalmind_protocol::fractal {
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::string::String;
    use std::option::Option;

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{
        Self, Organization, OrgAdminCap, ProtocolRegistry,
    };

    // ===== Events =====

    public struct SubOrgCreated has copy, drop {
        parent_org_id: ID,
        child_org_id: ID,
        admin: address,
        depth: u64,
    }

    public struct SubOrgDetached has copy, drop {
        parent_org_id: ID,
        child_org_id: ID,
    }

    // ===== Public Functions =====

    /// Create a sub-organization under a parent org. Parent admin only.
    /// Enforces MAX_FRACTAL_DEPTH.
    #[allow(lint(self_transfer))]
    public fun create_sub_organization(
        admin_cap: &OrgAdminCap,
        registry: &mut ProtocolRegistry,
        parent_org: &mut Organization,
        name: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        let parent_id = organization::org_id(parent_org);
        let sender = tx_context::sender(ctx);

        assert!(
            organization::admin_cap_org_id(admin_cap) == parent_id,
            constants::e_not_admin(),
        );
        assert!(organization::is_active(parent_org), constants::e_org_not_active());

        let parent_depth = organization::depth(parent_org);
        assert!(
            parent_depth + 1 <= constants::max_fractal_depth(),
            constants::e_max_depth_exceeded(),
        );

        let (child_id, child_cap) = organization::create_sub_organization(
            registry,
            parent_id,
            parent_depth,
            name,
            description,
            sender,
            ctx,
        );

        organization::add_child_org(parent_org, child_id);

        event::emit(SubOrgCreated {
            parent_org_id: parent_id,
            child_org_id: child_id,
            admin: sender,
            depth: parent_depth + 1,
        });

        transfer::public_transfer(child_cap, sender);
    }

    /// Detach a child org from its parent. Both parent and child admins must consent
    /// (we require parent admin cap + child admin cap).
    public fun detach_sub_organization(
        parent_admin_cap: &OrgAdminCap,
        child_admin_cap: &OrgAdminCap,
        parent_org: &mut Organization,
        child_org: &mut Organization,
    ) {
        let parent_id = organization::org_id(parent_org);
        let child_id = organization::org_id(child_org);

        assert!(
            organization::admin_cap_org_id(parent_admin_cap) == parent_id,
            constants::e_not_admin(),
        );
        assert!(
            organization::has_child_org(parent_org, child_id),
            constants::e_org_not_child(),
        );
        assert!(
            organization::admin_cap_org_id(child_admin_cap) == child_id,
            constants::e_not_admin(),
        );

        organization::remove_child_org(parent_org, child_id);
        organization::clear_parent(child_org);

        event::emit(SubOrgDetached {
            parent_org_id: parent_id,
            child_org_id: child_id,
        });
    }
}
