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

    def self.create_request(method, path)
      uri = path.is_a?(URI) ? path : url(path)
      request = method == :post ? Net::HTTP::Post.new(uri.request_uri) : Net::HTTP::Get.new(uri.request_uri)
      request['Host'] = uri.host
      request
    end
    def self.send(*args)
      case args[0]
      when Net::HTTPRequest
        request = args[0]
        method = request.method
        path = request.path
      else
        method = args[0]
        path = args[1]
      end

      uri = path.is_a?(URI) ? path : url(path)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if block_given?
        r = yield uri
        request = r if r.is_a? Net::HTTPRequest
      end
      request = create_request(method, uri) unless request

      https.start do |h|
        response = h.request(request)
      end
    end
  end
  module Authentication
    SESSIONS = ['cwssid', 'AWSELB']
    @@sessions = {}
    @@token = nil

    def self.logout
      @@sessions = {}
      @@token = nil
    end

    def self.session?
      !@@sessions.empty?
    end
    def self.token
      @@token
    end

    def self.login(email, password)
      request = HTTPS.create_request(:post, '/login.php')
      request.set_form_data('email' => email, 'password' => password)
      response = HTTPS.send(request)

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
    def self.initialize_session
      config = Config.instance
      login(config[:login][:email], config[:login][:password])
      @@token = parse_token(authenticated('/'))
    end

    def self.authenticated(path_args)
      initialize_session unless session?

      method = :get
      path = path_args
      if path_args.is_a? Hash
        method = path_args.keys.first
        path = path_args[method]
      end
      uri = HTTPS.url(path)

      HTTPS.send(method, uri) do |uri|
        r = yield uri if block_given?
        request = r ? r : HTTPS.create_request(method, uri)
        request['Cookie'] = @@sessions.keys.map{|k| '%s=%s' % [k, @@sessions[k]] }.join('; ')
        request
      end
    end

    private
    def self.parse_token(response)
      m = response.body.match(/ACCESS_TOKEN\s*=\s*['"]([^'"]+)['"];/)
      m ? m[1] : nil
    end
  end
end
