#[test_only]
module fractalmind_protocol::agent_tests {
    use sui::object;
    use sui::test_scenario::{Self as ts};
    use std::string;
    use std::vector;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::constants;

    const ADMIN: address = @0xA;
    const AGENT1: address = @0x1;

    fun setup_org(scenario: &mut ts::Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"AgentOrg"),
                string::utf8(b"org for agent tests"),
                ts::ctx(scenario),
            );
            organization::destroy_test_registry(registry);
        };
    }

    #[test]
    fun test_register_agent() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let tags = vector[string::utf8(b"dev"), string::utf8(b"qa")];
            agent::register_agent(&mut org, tags, ts::ctx(&mut scenario));
            assert!(organization::has_agent(&org, AGENT1), 0);
            assert!(organization::agent_count(&org) == 1, 1);
            ts::return_shared(org);
        };

        // Agent should have certificate
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            assert!(agent::cert_agent(&cert) == AGENT1, 2);
            assert!(agent::cert_status(&cert) == constants::agent_status_active(), 3);
            assert!(agent::cert_tasks_completed(&cert) == 0, 4);
            let tags = agent::cert_capability_tags(&cert);
            assert!(vector::length(&tags) == 2, 5);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4001)]
    fun test_register_agent_duplicate() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            // Should fail — already registered
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4004)]
    fun test_register_agent_too_many_tags() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let tags = vector[
                string::utf8(b"t1"), string::utf8(b"t2"), string::utf8(b"t3"),
                string::utf8(b"t4"), string::utf8(b"t5"), string::utf8(b"t6"),
                string::utf8(b"t7"), string::utf8(b"t8"), string::utf8(b"t9"),
                string::utf8(b"t10"), string::utf8(b"t11"), // 11 > MAX 10
            ];
            agent::register_agent(&mut org, tags, ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deactivate_agent_self() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::deactivate_agent(&mut cert, &mut org, ts::ctx(&mut scenario));
            assert!(agent::cert_status(&cert) == constants::agent_status_inactive(), 0);
            assert!(!organization::has_agent(&org, AGENT1), 1);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_remove_agent_by_admin() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut cert = ts::take_from_address<AgentCertificate>(&scenario, AGENT1);
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::remove_agent(&admin_cap, &mut cert, &mut org, ts::ctx(&mut scenario));
            assert!(agent::cert_status(&cert) == constants::agent_status_suspended(), 0);
            assert!(!organization::has_agent(&org, AGENT1), 1);
            ts::return_shared(org);
            ts::return_to_address(AGENT1, cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_update_capabilities() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let new_tags = vector[string::utf8(b"audit"), string::utf8(b"review")];
            agent::update_capabilities(&mut cert, new_tags, ts::ctx(&mut scenario));
            let tags = agent::cert_capability_tags(&cert);
            assert!(vector::length(&tags) == 2, 0);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2001)]
    fun test_deactivate_agent_with_mismatched_org_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_org(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(&mut scenario));
            ts::return_shared(org);
        };

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let registry = organization::create_test_registry(ts::ctx(&mut scenario));
            let mut fake_cert = agent::create_test_cert(object::id(&registry), AGENT1, ts::ctx(&mut scenario));
            organization::destroy_test_registry(registry);
            agent::deactivate_agent(&mut fake_cert, &mut org, ts::ctx(&mut scenario));
            ts::return_shared(org);
            agent::destroy_test_cert(fake_cert);
        };

        ts::end(scenario);
    }
}
