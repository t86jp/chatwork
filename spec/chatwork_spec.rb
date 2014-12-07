# -*- encoding: utf-8 -*-

require 'spec_helper'

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Chatwork do
  it 'has a version number' do
    expect(Chatwork::VERSION).not_to be nil
  end
end

describe Chatwork::Config do
  context 'constructor' do
    it 'should be returned an instance' do
      obj = described_class.instance
      expect(obj).to be_an_instance_of(Chatwork::Config)
    end
    context 'singleton' do
      it 'should be returned as same instance' do
        expect(described_class.instance).to be described_class.instance
      end
    end
    context 'load!' do
      it 'should return a value from the config yaml file' do
        obj = described_class.instance
        expect(obj).not_to be_load
        temp_config(:email => 'hoge@mail') do |f|
          obj.load!(f)
          expect(obj).to be_load
          expect(obj[:email]).to eq 'hoge@mail'
        end
      end
      it 'should raise an exception' do
        obj = described_class.instance
        temp_file do |f|
          f.puts 'not yaml'
          f.seek 0
          expect{ obj.load!(f) }.to raise_error(Chatwork::Error::ConfigError)
        end
      end
    end
    context 'save!' do
      it 'should export to a config file' do
        obj = described_class.instance
        obj[:test] = 'test'
        cloned = obj.clone
        temp_file do |f|
          obj.save!(f.to_path)
          obj.clear
          expect(obj).to be {}
          open(f.to_path) do |r|
            obj.load!(r)
            expect(obj).to eq cloned
          end
        end
      end
    end
    context 'default_config' do
      def cleanup(config)
        File.delete(config) if File.exists?(config)
      end
      before :each do
        @home = '/tmp'
        @config = File.join(@home, '.chatwork')
        cleanup(@config)
        @original = ENV['HOME']
        ENV['HOME'] = @home
      end
      after :each do
        ENV['HOME'] = @original
        cleanup(@config)
      end
      it 'should be returned a config file path in user\'s home directory' do
        obj = described_class.instance
        expect(obj.default_config).to eq @config
      end

      it 'should be loaded configs from the default file' do
        obj = described_class.instance
        open(@config, 'w+'){|f| f.puts('test: hoge') }
        obj.load!()
        expect(obj[:test]).to eq 'hoge'
      end
      it 'should be saved configs to the default file' do
        obj = described_class.instance
        obj.clear
        obj[:test] = 'hoge'
        obj.save!()
        config = File.read(@config)
        expect(config).to match /\ntest:\s*hoge\n/
      end
    end
  end
end

describe Chatwork::Authentication do
  LOGIN_USER = {
    :good => {:email => ENV['CHATWORK_DEV_EMAIL'], :password => ENV['CHATWORK_DEV_PASSWORD']},
    :bad  => {:email => 'user@email', :password => 'pass'}
  }
  def init_session(session)
    described_class.module_eval <<-EOM
      @@sessions = #{session}
    EOM
  end
  before :each do
    described_class.logout
  end

  context 'session?' do
    it 'should be true after authentication' do
      expect(described_class).not_to be_session
      init_session('{:key=>true}')
      expect(described_class).to be_session
    end
  end
  context 'logout' do
    it 'should destroy session' do
      expect(described_class).not_to be_session
      init_session('{:key=>true}')
      expect(described_class).to be_session
      described_class.logout
      expect(described_class).not_to be_session
    end
  end
  context 'login' do
    it 'should have session' do
      VCR.use_cassette('login_success') do
        described_class.login(LOGIN_USER[:good][:email], LOGIN_USER[:good][:password])
        expect(described_class).to be_session
      end
    end
    it 'should not have session' do
      VCR.use_cassette('login_fail') do
        expect { described_class.login(LOGIN_USER[:bad][:email], LOGIN_USER[:bad][:password]) }.to raise_error(Chatwork::Error::LoginError)
        expect(described_class).not_to be_session
      end
    end
  end
  context 'authenticated' do
    it 'should have session' do
      temp_config({:login => LOGIN_USER[:good]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('top_page_after_login') do
          expect(described_class).not_to be_session
          described_class.authenticated('/')
          expect(described_class).to be_session
        end
      end
    end
    it 'should not have session' do
      temp_config({:login => LOGIN_USER[:bad]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('login_fail') do
          expect(described_class).not_to be_session
          expect { described_class.authenticated('/') }.to raise_error(Chatwork::Error::LoginError)
          expect(described_class).not_to be_session
        end
      end
    end
  end
end

describe Chatwork::API do
  LOGIN_USER = {
    :good => {:email => ENV['CHATWORK_DEV_EMAIL'], :password => ENV['CHATWORK_DEV_PASSWORD']},
    :bad  => {:email => 'user@email', :password => 'pass'}
  }
  context 'get method' do
    it 'should send the command' do
      temp_config({:login => LOGIN_USER[:good]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('cmd_get_social_info') do
          res = described_class.get('get_social_info')
          expect(res).to be_is_a Hash
          expect(res).to be_key 'status'
        end
      end
    end
  end
  context 'post method' do
    it 'should send the command' do
      temp_config({:login => LOGIN_USER[:good]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('cmd_send_chat') do
          body = '{"text":"test message","room_id":"2268470"}'
          res = described_class.post('send_chat', {pdata:body})
          expect(res).to be_is_a Hash
        end
      end
    end
  end
end

describe Chatwork::Room do
  LOGIN_USER = {
    :good => {:email => ENV['CHATWORK_DEV_EMAIL'], :password => ENV['CHATWORK_DEV_PASSWORD']},
    :bad  => {:email => 'user@email', :password => 'pass'}
  }
  context 'get method' do
    it 'should send the command' do
      temp_config({:login => LOGIN_USER[:good]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('cmd_init_load') do
          room = described_class.find do |r|
            r['name'] == 'マイチャット'
          end
          expect(room.name).to eq 'マイチャット'
        end
      end
    end
  end
  context 'message' do
    it 'should post a new message' do
      temp_config({:login => LOGIN_USER[:good]}) do |f|
        Chatwork::Config.instance.load!(f)
        VCR.use_cassette('cmd_post_new_message') do
          room = described_class.find do |r|
            r['name'] == 'マイチャット'
          end
          expect(room.message('Hello!')).to be true
        end
      end
    end
  end
end
