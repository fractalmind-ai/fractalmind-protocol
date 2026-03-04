#[test_only]
module fractalmind_protocol::organization_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;

    use fractalmind_protocol::organization::{Self, ProtocolRegistry, Organization, OrgAdminCap};

    const ADMIN: address = @0xA;
    const USER_B: address = @0xB;

    #[test]
    fun test_create_organization() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"TestOrg"),
                string::utf8(b"A test org"),
                ts::ctx(&mut scenario),
            );
            assert!(organization::registry_org_count(&registry) == 1, 0);
            organization::destroy_test_registry(registry);
        };

        // Admin should receive the OrgAdminCap
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            ts::return_to_sender(&scenario, cap);
        };

        // Organization should be shared
        ts::next_tx(&mut scenario, ADMIN);
        {
            let org = ts::take_shared<Organization>(&scenario);
            assert!(organization::name(&org) == string::utf8(b"TestOrg"), 1);
            assert!(organization::is_active(&org), 2);
            assert!(organization::admin(&org) == ADMIN, 3);
            assert!(organization::depth(&org) == 0, 4);
            assert!(organization::agent_count(&org) == 0, 5);
            ts::return_shared(org);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3002)]
    fun test_create_organization_duplicate_name() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DupOrg"),
                string::utf8(b"first"),
                ts::ctx(&mut scenario),
            );
            // Should fail — name already taken
            organization::create_organization(
                &mut registry,
                string::utf8(b"DupOrg"),
                string::utf8(b"second"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3007)]
    fun test_create_organization_empty_name() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b""),
                string::utf8(b"empty name"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_deactivate_organization() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DeactOrg"),
                string::utf8(b"will deactivate"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            organization::deactivate_organization(&cap, &mut org, ts::ctx(&mut scenario));
            assert!(!organization::is_active(&org), 0);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_update_description() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DescOrg"),
                string::utf8(b"old desc"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            organization::update_description(&cap, &mut org, string::utf8(b"new desc"));
            assert!(organization::description(&org) == string::utf8(b"new desc"), 0);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_transfer_admin() {
        let mut scenario = ts::begin(ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"XferOrg"),
                string::utf8(b"admin transfer test"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            organization::transfer_admin(cap, &mut org, USER_B, ts::ctx(&mut scenario));
            assert!(organization::admin(&org) == USER_B, 0);
            ts::return_shared(org);
        };

        // USER_B should now have the admin cap
        ts::next_tx(&mut scenario, USER_B);
        {
            let cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }
}
