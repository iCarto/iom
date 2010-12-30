require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(:default, Rails.env) if defined?(Bundler)

module Iom
  class Application < Rails::Application
    config.action_view.javascript_expansions[:defaults] = %w()

    Paperclip::Railtie.insert

    config.encoding = "utf-8"

    config.filter_parameters += [:password]
  end
end

require 'open-uri'
require 'authenticated_system'
require 'acts_as_resource'
require 'will_paginate_random_collection'