require 'repositories'
require 'executor'
require 'tmpdir'

# Runs borges pack tests and check the results
class Pack
  def initialize(ops = {})
    @main_conf = ops[:conf]
    @conf = @main_conf['tests']['pack']
    @repos = ops[:repos]
  end

  def run(version)
    results = {}

    @conf.each do |name, resources|
      log("Pack test: #{name}")
      begin
        tmpdir = Dir.mktmpdir('test-pack')
        list = File.join(tmpdir, 'list')
        open(list, 'w') do |f|
          f.write(@repos.local_url(name))
        end

        exec = Executor.new(version.path, 'pack',
                            "--file=#{list}", "--to=#{tmpdir}")
        res = exec.run

        file_data = get_file_data(tmpdir)
        results[name] = {
          status: res[0],
          files: file_data,
          log: res[1]
        }

        siva_size = 0
        file_data.each {|f| siva_size += f[:size] }

        time = res[0][:wall]
        mem = res[0][:maxrss]
        siva = siva_size / 1024
        log("  time: #{time}s mem: #{mem} siva: #{siva}")
      ensure
        FileUtils.remove_entry(tmpdir)
      end
    end

    results
  end

  def get_file_data(tmpdir)
    files = Dir.glob(File.join(tmpdir, '*.siva'))

    files.map do |f|
      stat = File.stat(f)
      {
        name: f,
        size: stat.size
      }
    end
  end
end
