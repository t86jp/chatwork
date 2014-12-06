# -*- encoding: utf-8 -*-

require 'yaml'
require 'uri'
require 'net/https'
require 'chatwork/error'

module Chatwork
  module HTTPS
    PROTOCOL = 'https'
    DOMAIN = 'kcw.kddi.ne.jp'

    def self.url(path)
      URI.parse('%s://%s%s' % [PROTOCOL, DOMAIN, path])
    end

    def self.send(method, path)
      uri = url(path)

      request = method == :post ? Net::HTTP::Post.new(uri.request_uri) : Net::HTTP::Get.new(uri.request_uri)
      request['Host'] = uri.host
      yield request

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE

      https.start do |h|
        response = h.request(request)
      end
    end
  end
  module Authentication
    SESSIONS = ['cwssid', 'AWSELB']
    @@sessions = {}

    def self.logout
      @@sessions = {}
    end
    def self.session?
      !@@sessions.empty?
    end
    def self.login(email, password)
      response = HTTPS.send(:post, '/login.php') do |request|
        request.set_form_data('email' => email, 'password' => password)
      end

      case response
      when Net::HTTPFound
        response.get_fields('set-cookie').each do |c|
          cookie = c.split(/; */).first.split('=')
          return unless SESSIONS.any?{|k| cookie[0] == k }
          @@sessions[cookie[0].to_s] = cookie[1]
        end

        raise Chatwork::Error::LoginError.new unless session?
      else
        raise Chatwork::Error::LoginError.new
      end
    end
    def self.authenticated(path_args)
      unless session?
        config = Config.instance
        login(config[:login][:email], config[:login][:password])
      end

      method = :get
      path = path_args
      if path_args.is_a? Hash
        method = path_args.keys.first
        path = path_args[method]
      end
      HTTPS.send(method, path) do |request|
        request['Cookie'] = @@sessions.keys.map{|k| '%s=%s' % [k, @@sessions[k]] }.join('; ')
        yield request
      end
    end
  end
end
