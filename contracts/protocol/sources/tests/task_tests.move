#[test_only]
module fractalmind_protocol::task_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use std::vector;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::task::{Self, Task};
    use fractalmind_protocol::constants;

    const ADMIN: address = @0xA;
    const AGENT1: address = @0x1;

    fun setup_org_and_agent(scenario: &mut ts::Scenario) {
        // Create org
        ts::next_tx(scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"TaskOrg"),
                string::utf8(b"org for task tests"),
                ts::ctx(scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Register agent
        ts::next_tx(scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(scenario));
            ts::return_shared(org);
        };
    }

    #[test]
    fun test_create_task() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_and_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Build module"),
                string::utf8(b"Implement the core module"),
                ts::ctx(&mut scenario),
            );
            assert!(organization::task_count(&org) == 1, 0);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Task should be shared
        ts::next_tx(&mut scenario, AGENT1);
        {
            let task_obj = ts::take_shared<Task>(&scenario);
            assert!(task::task_status(&task_obj) == constants::task_status_created(), 1);
            assert!(task::task_creator(&task_obj) == AGENT1, 2);
            assert!(task::task_title(&task_obj) == string::utf8(b"Build module"), 3);
            ts::return_shared(task_obj);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_full_task_lifecycle() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_and_agent(&mut scenario);

        // Create task
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Full lifecycle"),
                string::utf8(b"Test complete flow"),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Assign (self-claim)
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let org = ts::take_shared<Organization>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::assign_task(&mut task_obj, &org, &cert, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_assigned(), 0);
            ts::return_shared(task_obj);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Submit
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::submit_task(&mut task_obj, string::utf8(b"my work output"), ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_submitted(), 1);
            ts::return_shared(task_obj);
        };

        // Verify
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::verify_task(&admin_cap, &mut task_obj, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_verified(), 2);
            ts::return_shared(task_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Complete
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            let mut cert = ts::take_from_address<AgentCertificate>(&scenario, AGENT1);
            task::complete_task(&admin_cap, &mut task_obj, &mut cert, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_completed(), 3);
            assert!(agent::cert_tasks_completed(&cert) == 1, 4);
            ts::return_shared(task_obj);
            ts::return_to_address(AGENT1, cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_reject_and_reassign() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_and_agent(&mut scenario);

        // Create task
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Reject test"),
                string::utf8(b"will be rejected"),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Assign
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let org = ts::take_shared<Organization>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::assign_task(&mut task_obj, &org, &cert, ts::ctx(&mut scenario));
            ts::return_shared(task_obj);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        // Submit
        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::submit_task(&mut task_obj, string::utf8(b"bad work"), ts::ctx(&mut scenario));
            ts::return_shared(task_obj);
        };

        // Reject
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            let mut cert = ts::take_from_address<AgentCertificate>(&scenario, AGENT1);
            task::reject_task(
                &admin_cap,
                &mut task_obj,
                &mut cert,
                string::utf8(b"not good enough"),
                ts::ctx(&mut scenario),
            );
            assert!(task::task_status(&task_obj) == constants::task_status_rejected(), 0);
            ts::return_shared(task_obj);
            ts::return_to_address(AGENT1, cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Re-assign after rejection
        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let org = ts::take_shared<Organization>(&scenario);
            let mut task_obj = ts::take_shared<Task>(&scenario);
            task::assign_task(&mut task_obj, &org, &cert, ts::ctx(&mut scenario));
            assert!(task::task_status(&task_obj) == constants::task_status_assigned(), 1);
            ts::return_shared(task_obj);
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5001)]
    fun test_submit_before_assign_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_and_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Bad flow"),
                string::utf8(b"skip assign"),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, AGENT1);
        {
            let mut task_obj = ts::take_shared<Task>(&scenario);
            // Should fail — status is Created, not Assigned
            task::submit_task(&mut task_obj, string::utf8(b"work"), ts::ctx(&mut scenario));
            ts::return_shared(task_obj);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5005)]
    fun test_create_task_empty_title() {
        let mut scenario = ts::begin(ADMIN);
        setup_org_and_agent(&mut scenario);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut org = ts::take_shared<Organization>(&scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b""),
                string::utf8(b"empty title"),
                ts::ctx(&mut scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }
}
