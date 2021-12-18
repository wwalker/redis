require "./value"
require "./errors"

module Redis
  struct Parser
    getter attributes = Map.new

    # Initialize a parser to read from the given IO
    def initialize(@io : IO)
    end

    # Read a `Redis::Value` from the parser's `IO`
    #
    # Example:
    #
    # ```
    # io = IO::Memory.new
    # io << "$3\r\n"
    # io << "foo\r\n"
    # io.rewind
    #
    # Parser.new(io).read # => "foo"
    # ```
    def read : Value
      case byte_marker = @io.read_byte
      when ':'
        parse_int.tap { crlf }
      when '*'
        read_array
      when '$'
        read_string
      when '+'
        @io.read_line
      when '%'
        read_map
      when '_'
        crlf
        nil
      when ','
        read_double
      when '#'
        read_boolean
      when '='
        read_verbatim_string
      when '~'
        read_set
      when '|'
        read_attributes
      when '-'
        type, message = @io.read_line.split(' ', 2)
        raise ERROR_MAP[type].new("#{type} #{message}")
      when nil
        raise IO::Error.new("Connection closed")
      else
        raise "Invalid byte marker: #{byte_marker.chr.inspect}"
      end
    end

    def read_array
      length = parse_int
      crlf
      if length >= 0
        Array.new(length) { read }
      end
    end

    def read_map
      size = parse_int
      crlf
      map = Map.new(initial_capacity: size)
      size.times do
        map[read] = read
      end
      map
    end

    def read_set
      size = parse_int
      crlf
      set = Set.new(initial_capacity: size)

      size.times { set << read }

      set
    end

    def read_string
      length = parse_int
      crlf
      if length >= 0
        value = @io.read_string length
        crlf
        value
      end
    end

    def read_double
      @io.read_line.to_f
    end

    def read_boolean
      case byte = @io.read_byte
      when 't'
        boolean = true
      when 'f'
        boolean = false
      when nil
        raise IO::Error.new("Connection closed")
      else
        raise Error.new("Unknown boolean: #{byte.chr.inspect}")
      end
      crlf
      boolean
    end

    def read_verbatim_string
      size = parse_int
      crlf
      @io.skip 4 # "txt:" or "mkd:"
      @io.read_string(size - 4) # size includes the bytes we skipped
    end

    def read_attributes
      @attributes.merge! read_map.as(Map)
      read
    end

    private def parse_int
      int = 0i64
      negative = false
      loop do
        if peek = @io.peek
          case next_byte = peek[0]
          when nil
            break
          when '-'
            negative = true
            @io.skip 1
          when '0'.ord..'9'.ord
            int = (int * 10) + (next_byte - '0'.ord)
            @io.skip 1
          else
            break
          end
        else
          break
        end
      end

      if negative
        -int
      else
        int
      end
    end

    def crlf
      @io.skip 2
    end
  end
end
