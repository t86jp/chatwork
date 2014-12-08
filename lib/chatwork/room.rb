# -*- encoding: utf-8 -*-

require 'json'
require 'chatwork/error'
require 'chatwork/api'

module Chatwork
  class Room
    attr_accessor :id, :name, :read_num, :chat_num
    @@data = nil

    # TODO: findやcreate_by_hashは移動
    def self.find
      unless @@data
        data = Chatwork::API.get('init_load')
        @@data = data['result']['room_dat'].reduce([]) do |r,d|
          room = d[1]
          room['id'] = d[0]
          r.push room
        end
      end

      raw = @@data.find do |r|
        yield r
      end
      raw ? create_by_hash(raw) : nil
    end

    private
    def self.create_by_hash(raw)
      obj = self.new

      obj.id = raw['id']
      obj.name = raw['name']
      obj.read_num = raw['read_num']
      obj.chat_num = raw['chat_num']

      obj
    end

    public
    def message(message)
      body = {
        :room_id => id,
        :text => message
      }
      response = Chatwork::API.post('send_chat', {'pdata' => JSON.dump(body)})
      response.is_a?(Hash) && response['status']['success']
    end
  end
end
