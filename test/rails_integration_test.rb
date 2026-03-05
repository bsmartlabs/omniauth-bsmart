# frozen_string_literal: true

require_relative 'test_helper'

require 'action_controller/railtie'
require 'cgi'
require 'json'
require 'logger'
require 'rack/test'
require 'rails'
require 'uri'
require 'webmock/minitest'

class RailsIntegrationSessionsController < ActionController::Base
  def create
    auth = request.env.fetch('omniauth.auth')
    render json: {
      uid: auth['uid'],
      name: auth.dig('info', 'name'),
      email: auth.dig('info', 'email'),
      credentials: auth['credentials']
    }
  end

  def failure
    render json: { error: params[:message] }, status: :unauthorized
  end
end

class RailsIntegrationApp < Rails::Application
  config.root = File.expand_path('..', __dir__)
  config.eager_load = false
  config.secret_key_base = 'bsmart-rails-integration-test-secret-key'
  config.active_support.cache_format_version = 7.1 if config.active_support.respond_to?(:cache_format_version=)

  if config.active_support.respond_to?(:to_time_preserves_timezone=) &&
     Rails.gem_version < Gem::Version.new('8.1.0')
    config.active_support.to_time_preserves_timezone = :zone
  end
  config.hosts.clear
  config.hosts << 'example.org'
  config.logger = Logger.new(nil)

  config.middleware.use OmniAuth::Builder do
    provider :bsmart, 'client-id', 'client-secret', scope: 'public'
  end

  routes.append do
    match '/auth/:provider/callback', to: 'rails_integration_sessions#create', via: %i[get post]
    get '/auth/failure', to: 'rails_integration_sessions#failure'
  end
end

RailsIntegrationApp.initialize! unless RailsIntegrationApp.initialized?

class RailsIntegrationTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    super
    @previous_test_mode = OmniAuth.config.test_mode
    @previous_allowed_request_methods = OmniAuth.config.allowed_request_methods
    @previous_request_validation_phase = OmniAuth.config.request_validation_phase

    OmniAuth.config.test_mode = false
    OmniAuth.config.allowed_request_methods = [:post]
    OmniAuth.config.request_validation_phase = nil
  end

  def teardown
    OmniAuth.config.test_mode = @previous_test_mode
    OmniAuth.config.allowed_request_methods = @previous_allowed_request_methods
    OmniAuth.config.request_validation_phase = @previous_request_validation_phase
    WebMock.reset!
    super
  end

  def app
    RailsIntegrationApp
  end

  def test_rails_request_and_callback_flow_uses_v6_user_endpoint
    stub_bsmart_token_exchange
    stub_bsmart_user

    post '/auth/bsmart'

    assert_equal 302, last_response.status

    authorize_uri = URI.parse(last_response['Location'])

    assert_equal 'www.bsmart.it', authorize_uri.host
    state = CGI.parse(authorize_uri.query).fetch('state').first

    get '/auth/bsmart/callback', { code: 'oauth-test-code', state: state }

    assert_equal 200, last_response.status

    payload = JSON.parse(last_response.body)

    assert_equal '42', payload['uid']
    assert_equal 'Ada Lovelace', payload['name']
    assert_equal 'teacher@example.test', payload['email']
    assert_equal 'access-token', payload.dig('credentials', 'token')
    assert_equal 'refresh-token', payload.dig('credentials', 'refresh_token')
    assert_equal 'public', payload.dig('credentials', 'scope')
    assert(payload.dig('credentials', 'expires'))

    assert_requested :post, 'https://www.bsmart.it/oauth/token', times: 1
    assert_requested :get, 'https://www.bsmart.it/api/v6/user', times: 1
  end

  def test_rails_request_and_callback_flow_falls_back_to_v6_me
    stub_bsmart_token_exchange
    stub_bsmart_user_not_found
    stub_bsmart_me

    post '/auth/bsmart'

    state = CGI.parse(URI.parse(last_response['Location']).query).fetch('state').first

    get '/auth/bsmart/callback', { code: 'oauth-test-code', state: state }

    assert_equal 200, last_response.status

    payload = JSON.parse(last_response.body)

    assert_equal '77', payload['uid']
    assert_equal 'Grace Hopper', payload['name']
    assert_equal 'grace@example.test', payload['email']

    assert_requested :get, 'https://www.bsmart.it/api/v6/user', times: 1
    assert_requested :get, 'https://www.bsmart.it/api/v6/me', times: 1
  end

  private

  def stub_bsmart_token_exchange
    stub_request(:post, 'https://www.bsmart.it/oauth/token').to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: {
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        scope: 'public',
        token_type: 'bearer',
        expires_in: 3600
      }.to_json
    )
  end

  def stub_bsmart_user
    stub_request(:get, 'https://www.bsmart.it/api/v6/user').to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: {
        id: 42,
        email: 'teacher@example.test',
        name: 'Ada',
        surname: 'Lovelace',
        avatar_url: 'https://www.bsmart.it/avatar/42.png',
        roles: ['teacher']
      }.to_json
    )
  end

  def stub_bsmart_user_not_found
    stub_request(:get, 'https://www.bsmart.it/api/v6/user').to_return(
      status: 404,
      headers: { 'Content-Type' => 'application/json' },
      body: { message: 'Not Found' }.to_json
    )
  end

  def stub_bsmart_me
    stub_request(:get, 'https://www.bsmart.it/api/v6/me').to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: {
        id: 77,
        email: 'grace@example.test',
        name: 'Grace',
        surname: 'Hopper',
        avatar_url: 'https://www.bsmart.it/avatar/77.png',
        roles: ['admin']
      }.to_json
    )
  end
end
