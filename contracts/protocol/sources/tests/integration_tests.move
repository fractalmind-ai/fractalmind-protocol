#[test_only]
module fractalmind_protocol::integration_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use std::vector;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap, ProtocolRegistry};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::task::{Self, Task};
    use fractalmind_protocol::fractal;
    use fractalmind_protocol::constants;

    const ADMIN: address = @0xA;
    const AGENT1: address = @0x1;
    const AGENT2: address = @0x2;

    /// Full integration: create org → register agents → create task → assign → submit → verify → complete → create sub-org
    #[test]
    fun test_full_protocol_flow() {
        let mut scenario = ts::begin(ADMIN);

        // 1. Create organization
        {
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"FractalDAO"),
                string::utf8(b"The fractal AI organization"),
                ts::ctx(&mut scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // 2. Register agent 1
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            let tags = vector[string::utf8(b"developer"), string::utf8(b"move")];
            agent::register_agent(&mut org, tags, ts::ctx(&mut scenario));
            assert!(organization::agent_count(&org) == 1, 0);
            ts::return_shared(org);
        };

        // 3. Register agent 2
        ts::next_tx(&mut scenario, AGENT2);
        {
            let mut org = ts::take_shared<Organization>(&scenario);
            agent::register_agent(&mut org, vector[string::utf8(b"qa")], ts::ctx(&mut scenario));
            assert!(organization::agent_count(&org) == 2, 1);
            ts::return_shared(org);
        };

        // 4. Agent1 creates a task
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Implement fractal nesting"),
                string::utf8(b"Build the fractal sub-org module"),
                ts::ctx(&mut scenario),
            );
            assert!(organization::task_count(&org) == 1, 2);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // 5. Agent1 self-claims the task
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let org = ts::take_shared<Organization>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::assign_task(&mut task_obj, &org, &cert, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_assigned(), 3);
            ts::return_shared(task_obj);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // 6. Agent1 submits work
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::submit_task(
                &mut task_obj,
                string::utf8(b"PR #42: fractal.move implementation"),
                ts::ctx(&mut scenario),
            );
            assert!(task::task_status(&task_obj) == constants::task_status_submitted(), 4);
            ts::return_shared(task_obj);
        };

        // 7. Admin verifies
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::verify_task(&admin_cap, &mut task_obj, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_verified(), 5);
            ts::return_shared(task_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // 8. Admin completes the task
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            let mut agent_cert = ts::take_from_address<AgentCertificate>(&scenario, AGENT1);
            task::complete_task(&admin_cap, &mut task_obj, &mut agent_cert, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_completed(), 6);
            assert!(agent::cert_tasks_completed(&agent_cert) == 1, 7);
            ts::return_shared(task_obj);
            ts::return_to_address(AGENT1, agent_cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // 9. Create a sub-organization (fractal nesting)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut parent = ts::take_shared<Organization>(&scenario);
            let mut registry = organization::create_test_registry(ts::ctx(&mut scenario));

            fractal::create_sub_organization(
                &admin_cap,
                &mut registry,
                &mut parent,
                string::utf8(b"FractalDAO-Engineering"),
                string::utf8(b"Engineering sub-division"),
                ts::ctx(&mut scenario),
            );

            assert!(organization::child_org_count(&parent) == 1, 8);
            assert!(organization::registry_org_count(&registry) == 1, 9);

            organization::destroy_test_registry(registry);
            ts::return_shared(parent);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }
}
