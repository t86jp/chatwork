# -*- encoding: utf-8 -*-

require 'yaml'
require 'chatwork/error'

module Chatwork
  class Config < Hash
    DEFAULT_CONFIG = '.chatwork'

    @loaded = false

    @@instance = nil
    def self.instance()
      @@instance = self.new if !@@instance
      @@instance
    end

    def default_config
      home = Dir.respond_to?(:home) ? Dir.home() : ENV['HOME']
      File::join(home, DEFAULT_CONFIG)
    end

    def load?
      @loaded ||= false
    end
    def load!(file = nil)
      file = default_config if file.nil? || !file

      yaml = file.instance_of?(String) && File.file?(file) ? YAML::load_file(file) : YAML::load(file)
      unless yaml.instance_of?(Hash)
        raise Error::ConfigError, '%s file is not yaml format' % [(file.is_a?(File) ? file.to_path : file)]
      end
      yaml.each do |k,v|
        self[k.to_sym] = v
      end
      @loaded = true

      self
    end
    def save!(file = nil)
      file = default_config if file.nil? || !file
      open(file, 'w+') do |f|
        f.puts YAML::dump(self.inject({}){|h,(k,v)| h[k.to_s] = v; h})
      end
    end
  end
end
