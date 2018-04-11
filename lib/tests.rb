require 'yaml'

require 'repositories'
require 'pack'

class Tests
  def initialize(conf_file)
    load_conf(conf_file)

    @repos = Repositories.new(repos: @conf['repositories'])
    @pack = Pack.new(repos: @repos, conf: @conf)
  end

  def load_conf(conf_file)
    begin
      text = File.read(conf_file)
      yaml = YAML.safe_load(text)
    rescue => e
      panic("Could not load test configuration: #{e.message}")
    end

    panic("Malformed test configuration file") if !yaml.is_a?(Hash)

    @conf = yaml
  end

  def run
    results = []
    results << pack

    results
  end

  def prepare
    @repos.prepare
    @repos.start_server
  end

  def stop
    @repos.stop_server
  end

  def pack
    @pack.run
  end
end
