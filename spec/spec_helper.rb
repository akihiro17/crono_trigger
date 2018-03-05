if ENV["CI"]
  require 'simplecov'
  SimpleCov.start

  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "rollbar"
require "crono_trigger"
require "serverengine"
require "crono_trigger/rollbar"

require "timecop"

Time.zone = "UTC"

case ENV["DB"]
when "mysql"
  ActiveRecord::Base.establish_connection(
    adapter: "mysql2",
    database: "test"
  )
else
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: ":memory:"
  )
end

class Notification < ActiveRecord::Base
  include CronoTrigger::Schedulable

  self.crono_trigger_options = {
    retry_limit: 1,
    error_handlers: [
      proc { |ex, record| record.class.results[record.id] = ex.message },
      :error_handler
    ]
  }

  @results = {}
  def self.results
    @results
  end

  after_execute :after

  def execute
    self.class.results[id] = "executed"
  end

  def after
  end

  def error_handler(ex)
    @error = ex
  end
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.migrate File.expand_path("../db/migrate", __FILE__), nil

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after(:each) do
    ActiveRecord::Base.connection.verify!
    Notification.delete_all
    Notification.results.clear
  end
end
