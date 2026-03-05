# frozen_string_literal: true

require_relative 'test_helper'

require 'oauth2'
require 'uri'

class OmniauthBsmartTest < Minitest::Test
  def build_strategy
    OmniAuth::Strategies::Bsmart.new(nil, 'client-id', 'client-secret')
  end

  def test_uses_current_bsmart_endpoints
    client_options = build_strategy.options.client_options

    assert_equal 'https://www.bsmart.it', client_options.site
    assert_equal '/oauth/authorize', client_options.authorize_url
    assert_equal '/oauth/token', client_options.token_url
  end

  def test_uid_info_and_extra_are_derived_from_raw_info
    strategy = build_strategy
    payload = {
      'id' => 42,
      'email' => 'teacher@example.test',
      'name' => 'Ada',
      'surname' => 'Lovelace',
      'avatar_url' => 'https://www.bsmart.it/avatar/42.png',
      'roles' => %w[teacher]
    }

    strategy.instance_variable_set(:@raw_info, payload)

    assert_equal '42', strategy.uid
    assert_equal(
      {
        name: 'Ada Lovelace',
        email: 'teacher@example.test',
        first_name: 'Ada',
        last_name: 'Lovelace',
        nickname: 'teacher@example.test',
        image: 'https://www.bsmart.it/avatar/42.png',
        roles: %w[teacher]
      },
      strategy.info
    )
    assert_equal({ 'raw_info' => payload }, strategy.extra)
  end

  def test_credentials_include_refresh_token_even_when_token_does_not_expire
    strategy = build_strategy
    token = FakeCredentialAccessToken.new(
      token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: nil,
      expires: false,
      params: { 'scope' => 'public' }
    )

    strategy.define_singleton_method(:access_token) { token }

    assert_equal(
      {
        'token' => 'access-token',
        'refresh_token' => 'refresh-token',
        'expires' => false,
        'scope' => 'public'
      },
      strategy.credentials
    )
  end

  def test_raw_info_calls_v6_user_and_memoizes
    strategy = build_strategy
    token = SequencedAccessToken.new([{ parsed: { 'id' => 42 } }])

    strategy.define_singleton_method(:access_token) { token }

    first_call = strategy.raw_info
    second_call = strategy.raw_info

    assert_equal({ 'id' => 42 }, first_call)
    assert_same first_call, second_call
    assert_equal 1, token.calls.length
    assert_equal '/api/v6/user', token.calls.first[:path]
  end

  def test_raw_info_falls_back_to_v6_me_on_not_found
    strategy = build_strategy
    token = SequencedAccessToken.new(
      [
        { error: OAuth2::Error.new(Struct.new(:status, :parsed).new(404, {})) },
        { parsed: { 'id' => 99, 'email' => 'student@example.test' } }
      ]
    )

    strategy.define_singleton_method(:access_token) { token }

    assert_equal({ 'id' => 99, 'email' => 'student@example.test' }, strategy.raw_info)
    request_paths = token.calls.map { |call| call[:path] }

    assert_equal ['/api/v6/user', '/api/v6/me'], request_paths
  end

  def test_raw_info_raises_for_non_fallback_oauth_errors
    strategy = build_strategy
    token = SequencedAccessToken.new([{ error: OAuth2::Error.new(Struct.new(:status, :parsed).new(500, {})) }])

    strategy.define_singleton_method(:access_token) { token }

    assert_raises(OAuth2::Error) { strategy.raw_info }
  end

  def test_request_phase_redirects_to_bsmart_with_expected_params
    previous_request_validation_phase = OmniAuth.config.request_validation_phase
    OmniAuth.config.request_validation_phase = nil

    app = ->(_env) { [404, { 'Content-Type' => 'text/plain' }, ['not found']] }
    strategy = OmniAuth::Strategies::Bsmart.new(app, 'client-id', 'client-secret')
    env = Rack::MockRequest.env_for('/auth/bsmart', method: 'POST')
    env['rack.session'] = {}

    status, headers, = strategy.call(env)

    assert_equal 302, status

    location = URI.parse(headers['Location'])
    params = URI.decode_www_form(location.query).to_h

    assert_equal 'www.bsmart.it', location.host
    assert_equal 'client-id', params.fetch('client_id')
    assert_equal 'public', params.fetch('scope')
  ensure
    OmniAuth.config.request_validation_phase = previous_request_validation_phase
  end

  class SequencedAccessToken
    attr_reader :calls

    def initialize(sequence)
      @sequence = sequence
      @calls = []
    end

    def get(path)
      @calls << { path: path }
      action = @sequence.shift || {}
      raise action[:error] if action[:error]

      Struct.new(:parsed).new(action[:parsed])
    end
  end

  class FakeCredentialAccessToken
    attr_reader :token, :refresh_token, :expires_at, :params

    def initialize(token:, refresh_token:, expires_at:, expires:, params:)
      @token = token
      @refresh_token = refresh_token
      @expires_at = expires_at
      @expires = expires
      @params = params
    end

    def expires?
      @expires
    end

    def [](key)
      { 'scope' => @params['scope'] }[key]
    end
  end
end
