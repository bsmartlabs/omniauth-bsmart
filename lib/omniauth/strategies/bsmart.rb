# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    # OmniAuth strategy for bSmart OAuth2.
    class Bsmart < OmniAuth::Strategies::OAuth2
      option :name, 'bsmart'
      option :authorize_options, %i[scope]
      option :scope, 'public'

      option :client_options,
             site: 'https://www.bsmart.it',
             authorize_url: '/oauth/authorize',
             token_url: '/oauth/token',
             connection_opts: {
               headers: {
                 user_agent: 'bsmartlabs-omniauth-bsmart gem',
                 accept: 'application/json'
               }
             }

      option :user_info_url, '/api/v6/user'
      option :me_url, '/api/v6/me'

      uid { raw_info['id']&.to_s }

      info do
        {
          name: full_name,
          email: raw_info['email'],
          first_name: raw_info['name'],
          last_name: raw_info['surname'],
          nickname: raw_info['email'],
          image: raw_info['avatar_url'],
          roles: raw_info['roles']
        }.compact
      end

      credentials do
        {
          'token' => access_token.token,
          'refresh_token' => access_token.refresh_token,
          'expires_at' => access_token.expires_at,
          'expires' => access_token.expires?,
          'scope' => token_scope
        }.compact
      end

      extra do
        {
          'raw_info' => raw_info
        }
      end

      def raw_info
        @raw_info ||= fetch_raw_info
      end

      private

      def full_name
        candidate = [raw_info['name'], raw_info['surname']].compact.join(' ').strip
        return candidate unless candidate.empty?

        raw_info['email']
      end

      def fetch_raw_info
        [options[:user_info_url], options[:me_url]].compact.uniq.each do |path|
          payload = access_token.get(path).parsed
          normalized = normalize_raw_info(payload)
          return normalized if normalized
        rescue ::OAuth2::Error => e
          raise unless fallback_user_info_error?(e)
        end

        {}
      end

      def normalize_raw_info(payload)
        return unless payload.is_a?(Hash)
        return payload if payload['id']

        %w[user data].each do |key|
          nested_payload = payload[key]
          return nested_payload if nested_payload.is_a?(Hash) && nested_payload['id']
        end

        nil
      end

      def fallback_user_info_error?(error)
        status = error.response&.status.to_i
        [404, 405].include?(status)
      end

      def token_scope
        token_params = access_token.respond_to?(:params) ? access_token.params : {}
        token_params['scope'] || (access_token['scope'] if access_token.respond_to?(:[]))
      end
    end
  end
end
