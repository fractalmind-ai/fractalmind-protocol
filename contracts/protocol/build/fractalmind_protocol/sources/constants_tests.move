#[test_only]
module fractalmind_protocol::constants_tests {
    use fractalmind_protocol::constants;

    #[test]
    fun test_error_codes_system() {
        assert!(constants::e_not_implemented() == 1000, 0);
        assert!(constants::e_invalid_state() == 1001, 1);
        assert!(constants::e_already_initialized() == 1002, 2);
    }

    #[test]
    fun test_error_codes_auth() {
        assert!(constants::e_unauthorized() == 2001, 0);
        assert!(constants::e_not_admin() == 2002, 1);
        assert!(constants::e_not_member() == 2003, 2);
    }

    #[test]
    fun test_error_codes_org() {
        assert!(constants::e_org_not_active() == 3001, 0);
        assert!(constants::e_org_name_taken() == 3002, 1);
        assert!(constants::e_org_already_deactivated() == 3003, 2);
        assert!(constants::e_max_depth_exceeded() == 3004, 3);
        assert!(constants::e_org_has_parent() == 3005, 4);
        assert!(constants::e_org_not_child() == 3006, 5);
        assert!(constants::e_empty_name() == 3007, 6);
    }

    #[test]
    fun test_error_codes_agent() {
        assert!(constants::e_agent_already_registered() == 4001, 0);
        assert!(constants::e_agent_not_active() == 4002, 1);
        assert!(constants::e_agent_not_found() == 4003, 2);
        assert!(constants::e_too_many_capability_tags() == 4004, 3);
    }

    #[test]
    fun test_error_codes_task() {
        assert!(constants::e_task_invalid_transition() == 5001, 0);
        assert!(constants::e_task_not_assignee() == 5002, 1);
        assert!(constants::e_task_already_assigned() == 5003, 2);
        assert!(constants::e_task_not_found() == 5004, 3);
        assert!(constants::e_task_empty_title() == 5005, 4);
    }

    #[test]
    fun test_system_limits() {
        assert!(constants::max_fractal_depth() == 8, 0);
        assert!(constants::max_capability_tags() == 10, 1);
    }

    #[test]
    fun test_agent_status_values() {
        assert!(constants::agent_status_active() == 0, 0);
        assert!(constants::agent_status_inactive() == 1, 1);
        assert!(constants::agent_status_suspended() == 2, 2);
    }

    #[test]
    fun test_task_status_values() {
        assert!(constants::task_status_created() == 0, 0);
        assert!(constants::task_status_assigned() == 1, 1);
        assert!(constants::task_status_submitted() == 2, 2);
        assert!(constants::task_status_verified() == 3, 3);
        assert!(constants::task_status_completed() == 4, 4);
        assert!(constants::task_status_rejected() == 5, 5);
    }
}
