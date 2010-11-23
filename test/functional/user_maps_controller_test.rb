require 'test_helper'

class UserMapsControllerTest < ActionController::TestCase
  setup do
    @user_map = user_maps(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:user_maps)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create user_map" do
    assert_difference('UserMap.count') do
      post :create, :user_map => @user_map.attributes
    end

    assert_redirected_to user_map_path(assigns(:user_map))
  end

  test "should show user_map" do
    get :show, :id => @user_map.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @user_map.to_param
    assert_response :success
  end

  test "should update user_map" do
    put :update, :id => @user_map.to_param, :user_map => @user_map.attributes
    assert_redirected_to user_map_path(assigns(:user_map))
  end

  test "should destroy user_map" do
    assert_difference('UserMap.count', -1) do
      delete :destroy, :id => @user_map.to_param
    end

    assert_redirected_to user_maps_path
  end
end
