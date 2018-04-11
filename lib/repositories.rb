require 'yaml'
require 'systemu'
require 'minitar'

def panic(text)
  STDERR.puts(text)
  exit(-1)
end

def log(text)
  STDERR.puts("#{Time.now}: #{text}")
end

# Repositories class holds repositories and related functionality
class Repositories
  def self.from_file(file)
    r = new

    begin
      text = File.read(file)
      yaml = YAML.safe_load(text)
    rescue => e
      panic("Could not load repositories yaml: #{e.message}")
    end

    panic("Malformed repository file") if !yaml.is_a?(Hash)

    yaml.each do |k,v|
      next if !v
      panic('Malformed repository file') unless v.is_a?(Hash)

      r.add_group(k, v)
    end

    r
  end

  def initialize(ops = {})
    @groups = Hash.new({})
    @repos = ops[:repos] || './repos'
    @tars = ops[:tars] || './tars'
    @server_thread = nil
    @server_cid = nil
  end

  def add_group(name, repos = {})
    if @groups.has_key?(name)
      @groups[name].merge!(repos)
    else
      @groups[name] = repos
    end
  end

  def prepare
    @groups.each do |group, g|
      log("Downloading group #{group}")
      next if group.empty?

      g.each do |name, url|
        log("  #{name}: #{url}")
        next if name.empty?

        path = File.join(@repos, group, name)
        if File.exist?(path)
          log("    repository already exist")
          next
        end

        start = Time.now

        begin
          rc = unpack(group, name, path)
          if rc == false
            download(url, path)
          end
        rescue => e
          panic("Could not prepare repository #{group}/#{name}: #{e}")
        end

        log("    took:  #{Time.now - start}s")
      end
    end
  end

  def unpack(group, name, path)
    tar = File.join(@tars, group, "#{name}.tar")
    return false if !File.exist?(tar)

    log("    tar: #{tar}")
    Minitar.unpack(tar, path)
  end

  def download(url, path)
    FileUtils.rm_rf(path) if File.exist?(path)
    execute(:clone, "--bare", url, path)
  end

  def execute(command, *params)
    command = "git #{command} #{params.join(' ')}"
    log("    command: #{command}")

    status, stdout, stderr = systemu command do |cid|
      yield(cid) if block_given?
    end

    if status.success?
      stdout
    else
      raise stderr
    end
  end

  def start_server(port = 9418)
    log("Starting server on port #{port}")

    @server_thread = Thread.new do
      execute('daemon', '--reuseaddr', "--base-path=#{@repos}",
              "--port=#{port}", '--export-all', @repos) do |cid|
        log("Executing daemon #{cid}")
        @server_cid = cid
      end
    end
  end

  def stop_server
    log('Stopping server')
    return unless @server_cid
    Process.kill("TERM", @server_cid)
    @server_thread.kill
  end
end
