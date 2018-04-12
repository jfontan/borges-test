require 'repositories'
require 'executor'
require 'tmpdir'

# Runs borges pack tests and check the results
class Pack
  def self.compare(conf, a, b)
    ok = true
    res = {}

    res[:memory] = compare_numbers(
      conf['memory_allowance'] || 10,
      a[:status][:maxrss],
      b[:status][:maxrss]
    )

    ok = false if res[:memory][:result] != :ok

    res[:time] = compare_numbers(
      conf['time_allowance'] || 10,
      a[:status][:wall],
      b[:status][:wall]
    )

    ok = false if res[:time][:result] != :ok

    siva_a = 0
    siva_b = 0
    a[:files].each {|f| siva_a += f[:size] }
    b[:files].each {|f| siva_b += f[:size] }

    res[:siva] = compare_numbers(
      conf['file_allowance'] || 10,
      siva_a,
      siva_b
    )

    ok = false if res[:siva][:result] != :ok

    return ok, res
  end

  def self.compare_numbers(allowance, a, b)
    diff = b - a
    res = :ok
    percentage = ( diff.to_f / a ) * 100

    res = :fail if percentage > allowance

    {
      before: a,
      after: b,
      percentage: percentage,
      result: res
    }
  end

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
