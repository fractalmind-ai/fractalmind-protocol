#[test_only]
module fractalmind_protocol::review_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use std::vector;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::task::{Self, Task};
    use fractalmind_protocol::review::{Self, Review};
    use fractalmind_protocol::constants;

    const ADMIN: address = @0xA;
    const ASSIGNEE: address = @0x1;
    const REVIEWER1: address = @0x3;
    const REVIEWER2: address = @0x4;

    fun setup_completed_task(scenario: &mut ts::Scenario) {
        // Create organization
        ts::next_tx(scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"ReviewOrg"),
                string::utf8(b"org for review tests"),
                ts::ctx(scenario),
            );
            organization::destroy_test_registry(registry);
        };

        // Register assignee and reviewers
        ts::next_tx(scenario, ASSIGNEE);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector[string::utf8(b"dev")], ts::ctx(scenario));
            ts::return_shared(org);
        };
        ts::next_tx(scenario, REVIEWER1);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector[string::utf8(b"qa")], ts::ctx(scenario));
            ts::return_shared(org);
        };
        ts::next_tx(scenario, REVIEWER2);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector[string::utf8(b"security")], ts::ctx(scenario));
            ts::return_shared(org);
        };

        // Create, assign, submit task
        ts::next_tx(scenario, ASSIGNEE);
        {
            let cert = ts::take_from_sender<AgentCertificate>(scenario);
            let mut org = ts::take_shared<Organization>(scenario);
            task::create_task(
                &mut org,
                &cert,
                string::utf8(b"Implement module"),
                string::utf8(b"prepare DAO implementation"),
                ts::ctx(scenario),
            );
            ts::return_shared(org);
            ts::return_to_sender(scenario, cert);
        };
        ts::next_tx(scenario, ASSIGNEE);
        {
            let cert = ts::take_from_sender<AgentCertificate>(scenario);
            let org = ts::take_shared<Organization>(scenario);
            let mut task_obj = ts::take_shared<Task>(scenario);
            task::assign_task(&mut task_obj, &org, &cert, ts::ctx(scenario));
            ts::return_shared(task_obj);
            ts::return_shared(org);
            ts::return_to_sender(scenario, cert);
        };
        ts::next_tx(scenario, ASSIGNEE);
        {
            let mut task_obj = ts::take_shared<Task>(scenario);
            task::submit_task(&mut task_obj, string::utf8(b"done"), ts::ctx(scenario));
            ts::return_shared(task_obj);
        };

        // Verify and complete as admin
        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(scenario);
            let mut task_obj = ts::take_shared<Task>(scenario);
            task::verify_task(&admin_cap, &mut task_obj, ts::ctx(scenario));
            ts::return_shared(task_obj);
            ts::return_to_sender(scenario, admin_cap);
        };
        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(scenario);
            let mut task_obj = ts::take_shared<Task>(scenario);
            let mut cert = ts::take_from_address<AgentCertificate>(scenario, ASSIGNEE);
            task::complete_task(&admin_cap, &mut task_obj, &mut cert, ts::ctx(scenario));
            ts::return_shared(task_obj);
            ts::return_to_address(ASSIGNEE, cert);
            ts::return_to_sender(scenario, admin_cap);
        };
    }

    fun create_review_2_of_2(scenario: &mut ts::Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(scenario);
            let task_obj = ts::take_shared<Task>(scenario);
            review::create_review(
                &admin_cap,
                &task_obj,
                vector[REVIEWER1, REVIEWER2],
                2,
                ts::ctx(scenario),
            );
            ts::return_shared(task_obj);
            ts::return_to_sender(scenario, admin_cap);
        };
    }

    #[test]
    fun test_review_pass_increases_reputation() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);
        create_review_2_of_2(&mut scenario);

        ts::next_tx(&mut scenario, REVIEWER1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };
        ts::next_tx(&mut scenario, REVIEWER2);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            let mut assignee_cert = ts::take_from_address<AgentCertificate>(&scenario, ASSIGNEE);
            review::finalize_review(&admin_cap, &mut review_obj, &mut assignee_cert, ts::ctx(&mut scenario));
            assert!(review::review_status(&review_obj) == constants::review_status_passed(), 0);
            assert!(agent::cert_reputation_score(&assignee_cert) == 1, 1);
            ts::return_shared(review_obj);
            ts::return_to_address(ASSIGNEE, assignee_cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_review_reject_decreases_reputation() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut cert = ts::take_from_address<AgentCertificate>(&scenario, ASSIGNEE);
            agent::increase_reputation(&mut cert, 2);
            ts::return_to_address(ASSIGNEE, cert);
        };

        create_review_2_of_2(&mut scenario);

        ts::next_tx(&mut scenario, REVIEWER1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_reject(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };
        ts::next_tx(&mut scenario, REVIEWER2);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_reject(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            let mut assignee_cert = ts::take_from_address<AgentCertificate>(&scenario, ASSIGNEE);
            review::finalize_review(&admin_cap, &mut review_obj, &mut assignee_cert, ts::ctx(&mut scenario));
            assert!(review::review_status(&review_obj) == constants::review_status_rejected(), 0);
            assert!(agent::cert_reputation_score(&assignee_cert) == 1, 1);
            ts::return_shared(review_obj);
            ts::return_to_address(ASSIGNEE, assignee_cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7004)]
    fun test_non_reviewer_cannot_submit_review() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);
        create_review_2_of_2(&mut scenario);

        ts::next_tx(&mut scenario, ASSIGNEE);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7003)]
    fun test_duplicate_reviewer_vote_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);
        create_review_2_of_2(&mut scenario);

        ts::next_tx(&mut scenario, REVIEWER1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7003)]
    fun test_create_review_with_duplicate_reviewers_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let task_obj = ts::take_shared<Task>(&scenario);
            review::create_review(
                &admin_cap,
                &task_obj,
                vector[REVIEWER1, REVIEWER1],
                2,
                ts::ctx(&mut scenario),
            );
            ts::return_shared(task_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7004)]
    fun test_create_review_with_assignee_as_reviewer_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let task_obj = ts::take_shared<Task>(&scenario);
            review::create_review(
                &admin_cap,
                &task_obj,
                vector[ASSIGNEE, REVIEWER1],
                2,
                ts::ctx(&mut scenario),
            );
            ts::return_shared(task_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7005)]
    fun test_invalid_threshold_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let task_obj = ts::take_shared<Task>(&scenario);
            review::create_review(
                &admin_cap,
                &task_obj,
                vector[REVIEWER1, REVIEWER2],
                3,
                ts::ctx(&mut scenario),
            );
            ts::return_shared(task_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7001)]
    fun test_finalize_without_quorum_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_completed_task(&mut scenario);
        create_review_2_of_2(&mut scenario);

        ts::next_tx(&mut scenario, REVIEWER1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            review::submit_review(&mut review_obj, &cert, constants::review_decision_approve(), ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let mut review_obj = ts::take_shared<Review>(&scenario);
            let mut assignee_cert = ts::take_from_address<AgentCertificate>(&scenario, ASSIGNEE);
            review::finalize_review(&admin_cap, &mut review_obj, &mut assignee_cert, ts::ctx(&mut scenario));
            ts::return_shared(review_obj);
            ts::return_to_address(ASSIGNEE, assignee_cert);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }
}
