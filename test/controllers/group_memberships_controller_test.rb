require "test_helper"

class GroupMembershipsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get group_memberships_create_url
    assert_response :success
  end

  test "should get destroy" do
    get group_memberships_destroy_url
    assert_response :success
  end
end
