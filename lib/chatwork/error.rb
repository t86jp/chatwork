# -*- encoding: utf-8 -*-

module Chatwork
  class Error < StandardError
  end
  class Error::ConfigError < Error
  end
  class Error::LoginError < Error
  end
  class Error::APIError < Error
  end
end
