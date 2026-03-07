#[test_only]
module fractalmind_protocol::profile_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::profile;

    const ADMIN: address = @0xA;
    const AGENT1: address = @0x1;
    const AGENT2: address = @0x2;

    fun setup_org_with_agent(scenario: &mut ts::Scenario) {
        // Admin creates org
        ts::next_tx(scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"ProfileOrg"),
                string::utf8(b"org for profile tests"),
                ts::ctx(scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Agent1 registers
        ts::next_tx(scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector[], ts::ctx(scenario));
            ts::return_shared(org);
        };
    }

    #[test]
    fun test_agent_create_profile() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);

            assert!(!profile::has_profile(&org, AGENT1), 0);

            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b"OpenClaw"),
                string::utf8(b"https://example.com/avatar.png"),
                ts::ctx(&mut scenario),
            );

            assert!(profile::has_profile(&org, AGENT1), 1);
            assert!(profile::profile_name(&org, AGENT1) == string::utf8(b"OpenClaw"), 2);
            assert!(
                profile::profile_avatar_url(&org, AGENT1) == string::utf8(b"https://example.com/avatar.png"),
                3,
            );

            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_agent_update_profile() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        // Create profile
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b"OpenClaw"),
                string::utf8(b""),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Update profile
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b"OpenClaw v2"),
                string::utf8(b"https://new-avatar.png"),
                ts::ctx(&mut scenario),
            );

            assert!(profile::profile_name(&org, AGENT1) == string::utf8(b"OpenClaw v2"), 0);
            assert!(
                profile::profile_avatar_url(&org, AGENT1) == string::utf8(b"https://new-avatar.png"),
                1,
            );

            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_admin_set_profile() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);

            profile::admin_set_profile(
                &admin_cap,
                &mut org,
                AGENT1,
                string::utf8(b"Agent-One"),
                string::utf8(b"https://avatar.io/1"),
                ts::ctx(&mut scenario),
            );

            assert!(profile::has_profile(&org, AGENT1), 0);
            assert!(profile::profile_name(&org, AGENT1) == string::utf8(b"Agent-One"), 1);

            ts::return_shared(org);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 8002)]
    fun test_empty_name_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b""), // empty name
                string::utf8(b""),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001)]
    fun test_wrong_cert_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        // Agent2 tries to use Agent1's cert (impossible in practice, but test the assert)
        // We simulate by having AGENT2 call set_profile with AGENT1's cert
        ts::next_tx(&mut scenario, AGENT2);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            // Create a test cert that belongs to AGENT1 but called by AGENT2
            let cert = agent::create_test_cert(
                organization::org_id(&org),
                AGENT1,
                ts::ctx(&mut scenario),
            );
            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b"Hacker"),
                string::utf8(b""),
                ts::ctx(&mut scenario),
            );
            agent::destroy_test_cert(cert);
            ts::return_shared(org);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4003)]
    fun test_admin_set_non_member_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);

            // AGENT2 is not a member
            profile::admin_set_profile(
                &admin_cap,
                &mut org,
                AGENT2,
                string::utf8(b"Ghost"),
                string::utf8(b""),
                ts::ctx(&mut scenario),
            );

            ts::return_shared(org);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_has_profile_false() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let org = ts::take_shared<Organization>(&scenario);
            assert!(!profile::has_profile(&org, AGENT1), 0);
            assert!(!profile::has_profile(&org, AGENT2), 1);
            ts::return_shared(org);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_empty_avatar_ok() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_with_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            profile::set_profile(
                &mut org,
                &cert,
                string::utf8(b"NoAvatar"),
                string::utf8(b""), // empty avatar is fine
                ts::ctx(&mut scenario),
            );

            assert!(profile::profile_name(&org, AGENT1) == string::utf8(b"NoAvatar"), 0);
            assert!(profile::profile_avatar_url(&org, AGENT1) == string::utf8(b""), 1);

            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }
}
