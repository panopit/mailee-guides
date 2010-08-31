module HerculesTriggers
  class Deployer
    def self.before_deploy(options)
      true
    end
    def self.after_deploy(options)
      `bundle exec rake`
    end
  end
end
