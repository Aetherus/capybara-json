require 'capybara'
require 'capybara/dsl'

module Capybara
  module Json
    def self.included(base)
      base.__send__(:include, Capybara::DSL) unless base < Capybara or base < Capybara::DSL 
      base.extend(self)
    end

    %w[ get delete ].each do |method|
      module_eval %{
        def #{method}(path, params = {}, env = {})
          page.driver.#{method}(path, params, env)
        end
      }
    end

    %w[ post put ].each do |method|
      module_eval %{
        def #{method}(path, json, env = {})
          page.driver.#{method}(path, json, env)
        end
      }
    end
  end

  module RackTestJson
    autoload :Driver, 'capybara/rack_test_json/driver'
  end
end

Capybara.register_driver :rack_test_json do |app|
  Capybara::RackTestJson::Driver.new(app)
end
