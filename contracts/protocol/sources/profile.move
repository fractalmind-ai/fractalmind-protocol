/// FractalMind Protocol — Agent Profile
/// AgentProfile stored as dynamic_object_field on Organization.
/// Both agents (via AgentCertificate) and admins (via OrgAdminCap) can set profiles.
module fractalmind_protocol::profile {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::dynamic_object_field as dof;
    use std::string::{Self, String};

    use fractalmind_protocol::constants;
    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};

    // ===== Structs =====

    /// Key for dynamic_object_field lookup. One profile per agent per org.
    public struct ProfileKey has copy, drop, store {
        agent: address,
    }

    /// Agent profile stored as DOF on Organization.
    public struct AgentProfile has key, store {
        id: UID,
        org_id: ID,
        agent: address,
        name: String,
        avatar_url: String,
        updated_at: u64,
    }

    // ===== Events =====

    public struct ProfileCreated has copy, drop {
        org_id: ID,
        agent: address,
        name: String,
    }

    public struct ProfileUpdated has copy, drop {
        org_id: ID,
        agent: address,
        name: String,
    }

    // ===== Public Functions =====

    /// Agent sets their own profile (create or update).
    /// Requires AgentCertificate to prove identity.
    public fun set_profile(
        org: &mut Organization,
        cert: &AgentCertificate,
        name: String,
        avatar_url: String,
        ctx: &mut TxContext,
    ) {
        let agent = agent::cert_agent(cert);
        // Verify cert belongs to caller
        assert!(agent == tx_context::sender(ctx), constants::e_unauthorized());
        // Verify cert is for this org
        assert!(agent::cert_org_id(cert) == organization::org_id(org), constants::e_unauthorized());
        // Verify agent is active in org
        assert!(organization::has_agent(org, agent), constants::e_agent_not_found());

        upsert_profile(org, agent, name, avatar_url, ctx);
    }

    /// Admin sets profile for any agent in the org.
    /// Requires OrgAdminCap to prove authority.
    public fun admin_set_profile(
        admin_cap: &OrgAdminCap,
        org: &mut Organization,
        agent: address,
        name: String,
        avatar_url: String,
        ctx: &mut TxContext,
    ) {
        assert!(
            organization::admin_cap_org_id(admin_cap) == organization::org_id(org),
            constants::e_not_admin(),
        );
        // Agent must be a member of the org
        assert!(organization::has_agent(org, agent), constants::e_agent_not_found());

        upsert_profile(org, agent, name, avatar_url, ctx);
    }

    // ===== Query Functions =====

    public fun has_profile(org: &Organization, agent: address): bool {
        let key = ProfileKey { agent };
        dof::exists_with_type<ProfileKey, AgentProfile>(organization::borrow_uid(org), key)
    }

    public fun profile_name(org: &Organization, agent: address): String {
        let key = ProfileKey { agent };
        assert!(
            dof::exists_with_type<ProfileKey, AgentProfile>(organization::borrow_uid(org), key),
            constants::e_profile_not_found(),
        );
        let profile = dof::borrow<ProfileKey, AgentProfile>(organization::borrow_uid(org), key);
        profile.name
    }

    public fun profile_avatar_url(org: &Organization, agent: address): String {
        let key = ProfileKey { agent };
        assert!(
            dof::exists_with_type<ProfileKey, AgentProfile>(organization::borrow_uid(org), key),
            constants::e_profile_not_found(),
        );
        let profile = dof::borrow<ProfileKey, AgentProfile>(organization::borrow_uid(org), key);
        profile.avatar_url
    }

    // ===== Internal =====

    /// Create or update an agent's profile on the org.
    fun upsert_profile(
        org: &mut Organization,
        agent: address,
        name: String,
        avatar_url: String,
        ctx: &mut TxContext,
    ) {
        // Validate inputs
        assert!(string::length(&name) > 0, constants::e_profile_empty_name());
        assert!(
            string::length(&name) <= constants::max_profile_name_length(),
            constants::e_profile_name_too_long(),
        );
        assert!(
            string::length(&avatar_url) <= constants::max_profile_url_length(),
            constants::e_profile_url_too_long(),
        );

        let org_id = organization::org_id(org);
        let key = ProfileKey { agent };
        let uid_mut = organization::borrow_uid_mut(org);
        let updated_at = tx_context::epoch_timestamp_ms(ctx);

        if (dof::exists_with_type<ProfileKey, AgentProfile>(uid_mut, key)) {
            // Update existing profile
            let profile = dof::borrow_mut<ProfileKey, AgentProfile>(uid_mut, key);
            profile.name = name;
            profile.avatar_url = avatar_url;
            profile.updated_at = updated_at;

            event::emit(ProfileUpdated { org_id, agent, name });
        } else {
            // Create new profile
            let profile = AgentProfile {
                id: object::new(ctx),
                org_id,
                agent,
                name,
                avatar_url,
                updated_at,
            };
            dof::add(uid_mut, key, profile);

            event::emit(ProfileCreated { org_id, agent, name });
        };
    }
}
