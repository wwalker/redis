module Redis
  # Values consumed and emitted by Redis can be strings, 64-bit integers, `nil`,
  # or an array of any of these types.
  alias Value = String |
                Int64 |
                Float64 |
                Bool |
                Nil |
                Set |
                Array(Value) |
                Hash(Value, Value)
  alias Map = Hash(Value, Value)
  alias Set = ::Set(Value)
end
