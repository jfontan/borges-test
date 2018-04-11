require 'ffi'

module Wait4
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  USECOND = 1_000_000

  attach_function :c_wait4, :wait4, [:int, :pointer, :int, :pointer], :int, blocking: true

  # Waits for a process and returns a hash with status and resource usage
  def self.wait4(pid)
    status = Wstatus.new
    status_ptr = FFI::Pointer.new(:uint8, status.pointer.address)
    rusage = Rusage.new
    rusage_ptr = FFI::Pointer.new(:uint8, rusage.pointer.address)

    # TODO: support options
    r = c_wait4(pid, status_ptr, 0, rusage_ptr)

    stime = rusage[:stime][:usec].to_f / USECOND + rusage[:stime][:sec]
    utime = rusage[:utime][:usec].to_f / USECOND + rusage[:utime][:sec]

    # TODO: add more resource counters
    data = {
      pid: r,
      status: status[:status],
      maxrss: rusage[:maxrss],
      stime: stime,
      utime: utime
    }

    return data
  end

  class Wstatus < FFI::Struct
    layout :status, :int
  end

  class Timeval < FFI::Struct
    layout :sec,  :time_t,
           :usec, :time_t
  end

  # from /usr/include/bits/types/struct_rusage.h
  class Rusage < FFI::Struct
    layout(
           # Total amount of user time used
           :utime,    Timeval,
           # Total amount of system time used
           :stime,    Timeval,
           # Maximum resident set size (in kilobytes)
           :maxrss,   :long,
           # Amount of sharing of text segment memory
           # with other processes (kilobyte-seconds)
           :ixrss,    :long,
           # Amount of data segment memory used (kilobyte-seconds)
           :idrss,    :long,
           # Amount of stack memory used (kilobyte-seconds)
           :isrss,    :long,
           # Number of soft page faults (i.e. those serviced by reclaiming
           # a page from the list of pages awaiting reallocation
           :minflt,   :long,
           # Number of hard page faults (i.e. those that required I/O).
           :majflt,   :long,
           # Number of times a process was swapped out of physical memory.
           :nswap,    :long,
           # Number of input operations via the file system.  Note: This
           # and `ru_oublock' do not include operations with the cache.
           :inblock,  :long,
           # Number of output operations via the file system.
           :outblock, :long,
           # Number of IPC messages sent.
           :msgsnd,   :long,
           # Number of IPC messages received.
           :msgrcv,   :long,
           # Number of signals delivered.
           :nsignals, :long,
           # Number of voluntary context switches, i.e. because the process
					 # gave up the process before it had to (usually to wait for some
           # resource to be available).
           :nvcsw,    :long,
           # Number of involuntary context switches, i.e. a higher priority
           # process became runnable or the current process used up its time
           # slice.
           :nivcsw,   :long
    )
  end
end
