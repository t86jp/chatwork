# -*- encoding: utf-8 -*-

require 'uri'
require 'json'
require 'chatwork/error'
require "chatwork/authentication"

module Chatwork
  module API
    ENDPOINT = '/gateway.php'

    def self.get(cmd)
      response = Chatwork::Authentication.authenticated(ENDPOINT) do |uri|
        queries = {
          :cmd => cmd,
          :_t  => Chatwork::Authentication.token
        }
        uri.query = queries.map do |k,v|
          URI.encode(k.to_s) + '=' + URI.encode(v.to_s)
        end.join('&')

        yield uri if block_given?
      end

      JSON.parse(response.body)
    end

    def self.post(cmd, body)
      response = Chatwork::Authentication.authenticated(ENDPOINT) do |uri|
        queries = {
          :cmd => cmd,
          :_t  => Chatwork::Authentication.token
        }
        uri.query = queries.map do |k,v|
          URI.encode(k.to_s) + '=' + URI.encode(v.to_s)
        end.join('&')

        yield uri if block_given?
        request = Chatwork::HTTPS.create_request(:post, uri)
        request.form_data = body
        request
      end

      JSON.parse(response.body)
    end
  end
end
