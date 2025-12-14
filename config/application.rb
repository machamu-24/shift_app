require_relative "boot"

require "rails/all"
require "set"


Bundler.require(*Rails.groups)

module ShiftApp
  class Application < Rails::Application
    config.load_defaults 7.1

    
    config.autoload_lib(ignore: %w(assets tasks))
    config.autoload_paths << Rails.root.join("app/errors")

   
  end
end
