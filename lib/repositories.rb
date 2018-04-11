require 'yaml'
require 'systemu'
require 'minitar'
require 'thread'

def panic(text)
  STDERR.puts(text)
  exit(-1)
end

def log(text)
  STDERR.puts("#{Time.now}: #{text}")
end

# Repositories class holds repositories and related functionality
class Repositories
  def initialize(ops = {})
    @repos = ops[:repos] || {}
    @repos_dir = ops[:repos_dir] || './repos'
    @tars_dir = ops[:tars_dir] || './tars'

    @server_thread = nil
    @server_cid = nil
    @server_mutex = Mutex.new
  end

  def prepare
    @repos.each do |name, url|
      log("#{name}: #{url}")
      next if name.empty?

      path = File.join(@repos_dir, name)
      if File.exist?(path)
        log("  repository already exists")
        next
      end

      start = Time.now

      begin
        rc = unpack(name, path)
        if rc == false
          download(url, path)
        end
      rescue => e
        panic("Could not prepare repository #{name}: #{e}")
      end

      log("  took:  #{Time.now - start}s")
    end
  end

  def unpack(name, path)
    tar = File.join(@tars_dir, "#{name}.tar")
    return false if !File.exist?(tar)

    log("  tar: #{tar}")
    Minitar.unpack(tar, path)
  end

  def download(url, path)
    FileUtils.rm_rf(path) if File.exist?(path)
    execute(:clone, "--bare", url, path)
  end

  def execute(command, *params)
    command = "git #{command} #{params.join(' ')}"
    log("  command: #{command}")

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

    server_thread = Thread.new do
      execute('daemon', '--reuseaddr', "--base-path=#{@repos_dir}",
              "--port=#{port}", '--export-all', @repos_dir) do |cid|
        log("Executing daemon #{cid}")
        @server_mutex.synchronize { @server_cid = cid }
      end
    end

    @server_mutex.synchronize { @server_thread = server_thread }

    # TODO: find out when the server is already running instead of sleeping
    sleep 2
  end

  def stop_server
    log('Stopping server')
    @server_mutex.synchronize do
      if @server_cid
        Process.kill("TERM", @server_cid)
        @server_thread.kill
        @server_cid = nil
      end
    end
  end

  def local_url(name, port = 9418)
    "git://localhost:#{port}/#{name}"
  end
end
