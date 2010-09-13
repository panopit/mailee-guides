module Hercules
  class Triggers
    def self.after_deploy(options)
      cmd = options[:shell]
      cmd.run "bundle exec rake"
    end
  end
end

