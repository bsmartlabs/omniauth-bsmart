# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth/bsmart/version'

Gem::Specification.new do |spec|
  spec.name = 'omniauth-bsmart'
  spec.version = OmniAuth::Bsmart::VERSION
  spec.authors = ['Claudio Poli']
  spec.email = ['masterkain@gmail.com']

  spec.summary = 'OmniAuth strategy for bSmart OAuth2 authentication.'
  spec.description = 'OAuth2 OmniAuth strategy that authenticates users against bSmart and maps v6 user profile data.'
  spec.homepage = 'https://github.com/bsmartlabs/omniauth-bsmart'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['source_code_uri'] = 'https://github.com/bsmartlabs/omniauth-bsmart'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/bsmartlabs/omniauth-bsmart/issues'
  spec.metadata['changelog_uri'] = 'https://github.com/bsmartlabs/omniauth-bsmart/releases'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*.rb',
    'README*',
    'LICENSE*',
    '*.gemspec'
  ]
  spec.require_paths = ['lib']

  spec.add_dependency 'cgi', '>= 0.3.6'
  spec.add_dependency 'omniauth-oauth2', '>= 1.8', '< 1.9'
end
