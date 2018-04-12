require 'wait4'
require 'shellwords'

# Executes commands and gets resource usage
class Executor
  def initialize(command, *params)
    @command = Shellwords.join([command] + params)
  end

  # Runs the command and returns status hash with resource usage and
  # stdout+stderr combined.
  def run
    out = ''

    status = stream do |std|
      while (buf = std.read(64))
        out << buf
      end
    end

    return status, out
  end

  def stream
    stat_out, stat_in = IO.pipe
    stdout_out, stdout_in = IO.pipe

    # Using wait4 in the main process sometimes did not provide results.
    # The command is executed in a separate process and result is sent
    # back using pipes. Both stdout and stderr are written to the same
    # pipe that is available in the main process.
    pid = fork do
      stat_out.close
      stdout_out.close
      stdout_in.sync = true

      start = Time.now
      # Both stdout and stderr are redirected to the same pipe
      pid = spawn(@command, out: stdout_in.fileno, err: stdout_in.fileno)
      data = Wait4.wait4(pid)
      total = Time.now - start

      data[:wall] = total

      # Send marshaled data to the main process
      d = Marshal.dump(data)
      stat_in.write(d)
      stat_in.flush
      stdout_in.close
    end

    stat_in.close
    stdout_in.close

    Thread.new do
      yield stdout_out
    end

    stat = Marshal.load(stat_out)

    Process.wait(pid)
    return stat
  end

end
