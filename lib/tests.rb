require 'yaml'
require 'json'

require 'repositories'
require 'pack'

class Tests
  def initialize(conf_file, versions)
    load_conf(conf_file)

    @repos = Repositories.new(repos: @conf['repositories'])
    @pack = Pack.new(repos: @repos, conf: @conf)
    @versions = load_versions(versions)
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

  def load_versions(versions)
    versions.map do |v|
      borges = Borges.new(v)
      borges.download
      borges
    end
  end

  def run
    results = []

    @versions.each do |v|
      log("#### VERSION #{v.name} ####")

      res = pack(v)
      path = "#{v.name}.json"
      open(path, "w") do |f|
        f.write(res.to_json)
      end

      results << res.merge({ _version: v.name })
    end

    @results = results
  end

  def prepare
    @repos.prepare
    @repos.start_server
  end

  def stop
    @repos.stop_server
  end

  def pack(version)
    @pack.run(version)
  end

  def pack_compare
    return nil if @results.length < 2

    res = {}
    @results[0..-2].each_with_index do |run, index|
      a = run
      b = @results[index+1]
      # pp [a, b, @results]
      name = "#{a[:_version]} - #{b[:_version]}"
      repos = a.keys - [:_version]

      repo_results = {}

      repos.each do |repo_name|
        repo_results[repo_name] = Pack.compare(@conf['conf'], a[repo_name], b[repo_name])
      end

      res[name] = repo_results
    end

    res
  end
end
