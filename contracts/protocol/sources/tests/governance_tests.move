#[test_only]
module fractalmind_protocol::governance_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use std::vector;

    use fractalmind_protocol::organization::{Self, Organization, OrgAdminCap};
    use fractalmind_protocol::agent::{Self, AgentCertificate};
    use fractalmind_protocol::governance::{Self, Governance, Proposal};
    use fractalmind_protocol::constants;

    const ADMIN: address = @0xA;
    const AGENT1: address = @0x1;
    const AGENT2: address = @0x2;

    fun setup_org_and_agents(scenario: &mut ts::Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            let mut registry = organization::create_test_registry(ts::ctx(scenario));
            organization::create_organization(
                &mut registry,
                string::utf8(b"GovOrg"),
                string::utf8(b"org for governance tests"),
                ts::ctx(scenario),
            );
            organization::destroy_test_registry(registry);
        };

        ts::next_tx(scenario, AGENT1);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(scenario));
            ts::return_shared(org);
        };

        ts::next_tx(scenario, AGENT2);
        {
            let mut org = ts::take_shared<Organization>(scenario);
            agent::register_agent(&mut org, vector::empty(), ts::ctx(scenario));
            ts::return_shared(org);
        };
    }

    fun setup_governance_with_started_proposal(scenario: &mut ts::Scenario, voting_deadline: u64) {
        setup_org_and_agents(scenario);

        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(scenario);
            let org = ts::take_shared<Organization>(scenario);
            governance::create_governance(&admin_cap, &org, ts::ctx(scenario));
            ts::return_shared(org);
            ts::return_to_sender(scenario, admin_cap);
        };

        ts::next_tx(scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(scenario);
            let mut governance_obj = ts::take_shared<Governance>(scenario);
            let org = ts::take_shared<Organization>(scenario);
            governance::create_proposal(
                &mut governance_obj,
                &org,
                &cert,
                string::utf8(b"Enable QA policy"),
                string::utf8(b"Switch to stricter review"),
                voting_deadline,
                b"payload",
                ts::ctx(scenario),
            );
            ts::return_shared(org);
            ts::return_shared(governance_obj);
            ts::return_to_sender(scenario, cert);
        };

        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(scenario);
            let governance_obj = ts::take_shared<Governance>(scenario);
            let mut proposal = ts::take_shared<Proposal>(scenario);
            governance::start_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(scenario));
            ts::return_shared(proposal);
            ts::return_shared(governance_obj);
            ts::return_to_sender(scenario, admin_cap);
        };
    }

    #[test]
    fun test_create_governance_and_proposal() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 1000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let governance_obj = ts::take_shared<Governance>(&scenario);
            let proposal = ts::take_shared<Proposal>(&scenario);
            assert!(governance::governance_proposal_count(&governance_obj) == 1, 0);
            assert!(governance::proposal_status(&proposal) == constants::proposal_status_voting(), 1);
            ts::return_shared(proposal);
            ts::return_shared(governance_obj);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_finalize_pass_and_execute() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 2);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, constants::vote_for(), ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, AGENT2);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, constants::vote_abstain(), ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let governance_obj = ts::take_shared<Governance>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::close_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            governance::finalize_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            assert!(governance::proposal_status(&proposal) == constants::proposal_status_passed(), 0);
            governance::execute_proposal(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            assert!(governance::proposal_status(&proposal) == constants::proposal_status_executed(), 1);
            ts::return_shared(proposal);
            ts::return_shared(governance_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_finalize_rejected_on_tie() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 2);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, constants::vote_for(), ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, AGENT2);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, constants::vote_against(), ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let governance_obj = ts::take_shared<Governance>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::close_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            governance::finalize_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            assert!(governance::proposal_status(&proposal) == constants::proposal_status_rejected(), 0);
            ts::return_shared(proposal);
            ts::return_shared(governance_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6003)]
    fun test_double_vote_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 1000);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, constants::vote_for(), ts::ctx(&mut scenario));
            governance::cast_vote(&mut proposal, &cert, constants::vote_for(), ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6002)]
    fun test_invalid_vote_option_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 1000);

        ts::next_tx(&mut scenario, AGENT1);
        {
            let cert = ts::take_from_sender<AgentCertificate>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::cast_vote(&mut proposal, &cert, 9, ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_to_sender(&scenario, cert);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6005)]
    fun test_finalize_before_deadline_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_governance_with_started_proposal(&mut scenario, 1000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<OrgAdminCap>(&scenario);
            let governance_obj = ts::take_shared<Governance>(&scenario);
            let mut proposal = ts::take_shared<Proposal>(&scenario);
            governance::finalize_voting(&admin_cap, &governance_obj, &mut proposal, ts::ctx(&mut scenario));
            ts::return_shared(proposal);
            ts::return_shared(governance_obj);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }
}
