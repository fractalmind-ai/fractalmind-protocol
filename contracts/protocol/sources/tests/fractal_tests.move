#[test_only]
module fractalmind_protocol::fractal_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::fractal;

    const ADMIN: address = @0xA;

    #[test]
    fun test_create_sub_organization() {
        let mut scenario = ts::begin(ADMIN);

        // Create registry + root org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"RootOrg"),
                string::utf8(b"root"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Create sub-org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut parent = ts::take_shared<Organization>(&scenario);
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));

            fractal::create_sub_organization(
                &admin_cap,
                &mut registry,
                &mut parent,
                string::utf8(b"SubOrg1"),
                string::utf8(b"child org"),
                ts::ctx(&mut scenario),
            );

            assert!(organization::child_org_count(&parent) == 1, 0);
            assert!(organization::registry_org_count(&registry) == 1, 1);

            organization::destroy_test_registry(registry);
            ts::return_shared(parent);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Verify admin received a second cap for the child
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ids = ts::ids_for_sender<OrgAdminCap>(&scenario);
            assert!(std::vector::length(&ids) == 2, 2);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_detach_sub_organization() {
        let mut scenario = ts::begin(ADMIN);

        // Create root org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DetachRoot"),
                string::utf8(b"root for detach test"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Create sub-org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut parent = ts::take_shared<Organization>(&scenario);
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));

            fractal::create_sub_organization(
                &admin_cap,
                &mut registry,
                &mut parent,
                string::utf8(b"DetachChild"),
                string::utf8(b"will be detached"),
                ts::ctx(&mut scenario),
            );

            organization::destroy_test_registry(registry);
            ts::return_shared(parent);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Detach: get both admin caps and both orgs, match them correctly
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap_ids = ts::ids_for_sender<OrgAdminCap>(&scenario);
            let mut cap_a = ts::take_from_sender_by_id<OrgAdminCap>(
                &scenario,
                *std::vector::borrow(&cap_ids, 0),
            );
            let mut cap_b = ts::take_from_sender_by_id<OrgAdminCap>(
                &scenario,
                *std::vector::borrow(&cap_ids, 1),
            );

            let mut org_a = ts::take_shared<Organization>(&scenario);
            let mut org_b = ts::take_shared<Organization>(&scenario);

            // Figure out which org is the parent (has children)
            // and match caps to orgs by org_id
            let org_a_is_parent = organization::child_org_count(&org_a) > 0;

            if (org_a_is_parent) {
                // org_a is parent. Match cap to org_a.
                let cap_a_matches_a = organization::admin_cap_org_id(&cap_a) == organization::org_id(&org_a);
                if (cap_a_matches_a) {
                    // cap_a -> parent (org_a), cap_b -> child (org_b)
                    fractal::detach_sub_organization(&cap_a, &cap_b, &mut org_a, &mut org_b);
                } else {
                    // cap_b -> parent (org_a), cap_a -> child (org_b)
                    fractal::detach_sub_organization(&cap_b, &cap_a, &mut org_a, &mut org_b);
                };
                assert!(organization::child_org_count(&org_a) == 0, 0);
                assert!(option::is_none(&organization::parent_org(&org_b)), 1);
            } else {
                // org_b is parent
                let cap_a_matches_b = organization::admin_cap_org_id(&cap_a) == organization::org_id(&org_b);
                if (cap_a_matches_b) {
                    // cap_a -> parent (org_b), cap_b -> child (org_a)
                    fractal::detach_sub_organization(&cap_a, &cap_b, &mut org_b, &mut org_a);
                } else {
                    // cap_b -> parent (org_b), cap_a -> child (org_a)
                    fractal::detach_sub_organization(&cap_b, &cap_a, &mut org_b, &mut org_a);
                };
                assert!(organization::child_org_count(&org_b) == 0, 2);
                assert!(option::is_none(&organization::parent_org(&org_a)), 3);
            };

            ts::return_shared(org_b);
            ts::return_shared(org_a);
            ts::return_to_sender(&scenario, cap_b);
            ts::return_to_sender(&scenario, cap_a);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_nested_fractal_depth() {
        let mut scenario = ts::begin(ADMIN);

        // Create root
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DepthRoot"),
                string::utf8(b"depth test root"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Create child at depth 1
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut parent = ts::take_shared<Organization>(&scenario);
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));

            fractal::create_sub_organization(
                &admin_cap,
                &mut registry,
                &mut parent,
                string::utf8(b"Depth1"),
                string::utf8(b"depth 1"),
                ts::ctx(&mut scenario),
            );

            assert!(organization::depth(&parent) == 0, 0);
            assert!(organization::child_org_count(&parent) == 1, 1);

            organization::destroy_test_registry(registry);
            ts::return_shared(parent);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2002)]
    fun test_detach_sub_organization_with_wrong_child_cap_fails() {
        let mut scenario = ts::begin(ADMIN);

        // Create root org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"DetachWrongCapRoot"),
                string::utf8(b"root for wrong child cap test"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Create sub-org
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut parent = ts::take_shared<Organization>(&scenario);
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));

            fractal::create_sub_organization(
                &admin_cap,
                &mut registry,
                &mut parent,
                string::utf8(b"DetachWrongCapChild"),
                string::utf8(b"child"),
                ts::ctx(&mut scenario),
            );

            organization::destroy_test_registry(registry);
            ts::return_shared(parent);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Try detach with parent cap passed as both parent and child cap.
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap_ids = ts::ids_for_sender<OrgAdminCap>(&scenario);
            let cap_a = ts::take_from_sender_by_id<OrgAdminCap>(
                &scenario,
                *std::vector::borrow(&cap_ids, 0),
            );
            let cap_b = ts::take_from_sender_by_id<OrgAdminCap>(
                &scenario,
                *std::vector::borrow(&cap_ids, 1),
            );

            let mut org_a = ts::take_shared<Organization>(&scenario);
            let mut org_b = ts::take_shared<Organization>(&scenario);

            let org_a_is_parent = organization::child_org_count(&org_a) > 0;
            if (org_a_is_parent) {
                let parent_cap = if (organization::admin_cap_org_id(&cap_a) == organization::org_id(&org_a)) { &cap_a } else { &cap_b };
                fractal::detach_sub_organization(parent_cap, parent_cap, &mut org_a, &mut org_b);
            } else {
                let parent_cap = if (organization::admin_cap_org_id(&cap_a) == organization::org_id(&org_b)) { &cap_a } else { &cap_b };
                fractal::detach_sub_organization(parent_cap, parent_cap, &mut org_b, &mut org_a);
            };

            ts::return_shared(org_b);
            ts::return_shared(org_a);
            ts::return_to_sender(&scenario, cap_b);
            ts::return_to_sender(&scenario, cap_a);
        };

        ts::end(scenario);
    }
}
