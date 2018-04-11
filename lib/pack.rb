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

        results[name] = {
          status: res[0],
          log: res[1]
        }
      ensure
        FileUtils.remove_entry(tmpdir)
      end
    end

    results
  end
end
