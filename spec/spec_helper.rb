$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rubygems'
require 'rspec'
require 'chatwork'
require 'webmock/rspec'
require 'vcr'
require 'tempfile'
require 'yaml'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

VCR.configure do |c|
  c.default_cassette_options = {
    'match_requests_on' => [:uri, :body, :method]
  }
  c.cassette_library_dir = 'spec/fixtures/vcr'
  c.hook_into :webmock
end

RSpec.configure do |config|
  
end

def temp_file
  temp = Tempfile.new('chatwork.spec.')
  yield temp
  temp.close
end

def temp_config(config)
  temp_file do |f|
    yaml = config.inject({}){|h,(k,v)| h[k.to_s] = v; h}
    f.puts(YAML.dump(yaml))
    f.seek 0
    yield f
  end
end
