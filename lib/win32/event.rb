require 'win32/ipc'

# The Win32 module serves as a namespace only.
module Win32

  # The Event class encapsulates Windows event objects.
  class Event < Ipc
    ffi_lib :kernel32

    class SecurityAttributes < FFI::Struct
      layout(
        :nLength, :ulong,
        :lpSecurityDescriptor, :pointer,
        :bInheritHandle, :bool
      )
    end

    attach_function :CreateEvent, :CreateEventW, [:pointer, :bool, :bool, :buffer_in], :ulong
    attach_function :OpenEvent, :OpenEventW, [:ulong, :bool, :buffer_in], :ulong
    attach_function :SetEvent, [:ulong], :bool
    attach_function :ResetEvent, [:ulong], :bool

    private_class_method :CreateEvent, :OpenEvent, :SetEvent, :ResetEvent

    INVALID_HANDLE_VALUE = 0xFFFFFFFF
    EVENT_ALL_ACCESS     = 0x1F0003

    # This is the error raised if any of the Event methods fail.
    class Error < StandardError; end

    # The version of the win32-event library
    VERSION = '0.6.0'

    # The name of the Event object. The default is nil
    #
    attr_reader :name

    # Indicates whether or not the Event requires use of the ResetEvent()
    # function set the state to nonsignaled. The default is false
    #
    attr_reader :manual_reset

    # The initial state of the Event object. If true, the initial state
    # is signaled. Otherwise, it is non-signaled. The default is false.
    #
    attr_reader :initial_state

    # Creates and returns new Event object.  If +name+ is omitted, the
    # Event object is created without a name, i.e. it's anonymous.
    #
    # If +name+ is provided and it already exists, then it is opened
    # instead and the +manual_reset+ and +initial_state+ parameters are
    # ignored.
    #
    # If the +man_reset+ parameter is set to +true+, then it creates an Event
    # object which requires use of the Event#reset method in order to set the
    # state to non-signaled. If this parameter is false (the default) then
    # the system automatically resets the state to non-signaled after a
    # single waiting thread has been released.
    #
    # If the +init_state+ parameter is +true+, the initial state of the
    # Event object is signaled; otherwise, it is nonsignaled (the default).
    #
    # If the +inherit+ parameter is true, then processes created by this
    # process will inherit the handle. Otherwise they will not.
    #
    # In block form this will automatically close the Event object at the
    # end of the block.
    #
    def initialize(name=nil, man_reset=false, init_state=false, inherit=true)
      @name          = name
      @manual_reset  = man_reset
      @initial_state = init_state
      @inherit       = inherit

      if name.is_a?(String)
        if name.encoding.to_s != 'UTF-16LE'
          name = name + 0.chr
          name.encode!('UTF-16LE')
        end
      else
        raise TypeError if name
      end

      if inherit
        sec = SecurityAttributes.new
        sec[:nLength] = SecurityAttributes.size
        sec[:bInheritHandle] = inherit
      else
        sec = nil
      end

      handle = CreateEvent(sec, manual_reset, initial_state, name)

      if handle == 0 || handle == INVALID_HANDLE_VALUE
        raise SystemCallError.new("CreateEvent", FFI.errno)
      end

      super(handle)
    end

    # Open an existing Event by +name+. The +inherit+ argument sets whether
    # or not the object was opened such that a process created by the
    # CreateProcess() function (a Windows API function) can inherit the
    # handle. The default is true.
    #
    # This method is essentially identical to Event.new, except that the
    # options for manual_reset and initial_state cannot be set (since they
    # are already set). Also, this method will raise an Event::Error if the
    # event doesn't already exist.
    #
    # If you want "open or create" semantics, then use Event.new.
    #
    def self.open(name, inherit=true, &block)
      raise TypeError unless name.is_a?(String)

      if name.encoding.to_s != 'UTF-16LE'
        oname = name + 0.chr
        oname.encode!('UTF-16LE')
      else
        oname = name.dup
      end

      # This block of code is here strictly to force an error if the user
      # tries to open an event that doesn't already exist.
      begin
        h = OpenEvent(EVENT_ALL_ACCESS, inherit, oname)

        if h == 0 || h == INVALID_HANDLE_VALUE
          raise SystemCallError.new("OpenEvent", FFI.errno)
        end
      ensure
        CloseHandle(h) if h
      end

      self.new(name, false, false, inherit, &block)
    end

    # Returns whether or not the object was opened such that a process
    # created by the CreateProcess() function (a Windows API function) can
    # inherit the handle. The default is true.
    #
    def inheritable?
      @inherit
    end

    # Sets the Event object to a non-signaled state.
    #
    def reset
      unless ResetEvent(@handle)
        raise SystemCallError.new("ResetEvent", FFI.errno)
      end
      @signaled = false
    end

    # Sets the Event object to a signaled state.
    #
    def set
      unless SetEvent(@handle)
        raise SystemCallError.new("SetEvent", FFI.errno)
      end
      @signaled = true
    end

    # Synonym for Event#reset if +bool+ is false, or Event#set
    # if +bool+ is true.
    #
    def signaled=(bool)
      if bool
        set
      else
        reset
      end
    end
  end
end
