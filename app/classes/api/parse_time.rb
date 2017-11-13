# API
class API
  def parse_time(key, args = {})
    declare_parameter(key, :time, args)
    str = get_param(key)
    return args[:default] unless str
    parse_time_yyyymmddhhmmss(str)
  rescue ArgumentError
    raise BadParameterValue.new(str, :time)
  end

  def parse_time_range(key, args = {})
    declare_parameter(key, :time_range, args)
    str = get_param(key)
    return args[:default] unless str
    parse_time_range_all_patterns(str)
  rescue ArgumentError
    raise BadParameterValue.new(str, :time_range)
  end

  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/CyclomaticComplexity
  def parse_time_range_all_patterns(str)
    parse_time_range_yyyymmddhhmmss_x2(str) ||
      parse_time_range_yyyymmddhhmm_x2(str) ||
      parse_time_range_yyyymmddhh_x2(str) ||
      parse_time_range_yyyymmdd_x2(str) ||
      parse_time_range_yyyymm_x2(str) ||
      parse_time_range_yyyy_x2(str) ||
      parse_time_range_yyyymmddhhmmss(str) ||
      parse_time_range_yyyymmddhhmm(str) ||
      parse_time_range_yyyymmddhh(str) ||
      parse_time_range_yyyymmdd(str) ||
      parse_time_range_yyyymm(str) ||
      parse_time_range_yyyy(str) ||
      raise(ArgumentError)
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def parse_time_range_yyyymmddhhmmss_x2(str)
    match = str.match(/^(#{YYYYMMDDHHMMSS1})\s*-\s*(#{YYYYMMDDHHMMSS1})$/) ||
            str.match(/^(#{YYYYMMDDHHMMSS2})\s*-\s*(#{YYYYMMDDHHMMSS2})$/) ||
            str.match(/^(#{YYYYMMDDHHMMSS3})\s*-\s*(#{YYYYMMDDHHMMSS3})$/)
    return unless match
    from = strip_time(match[1]) + " UTC"
    to   = strip_time(match[2]) + " UTC"
    from = DateTime.parse(from)
    to   = DateTime.parse(to)
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmddhhmm_x2(str)
    match = str.match(/^(#{YYYYMMDDHHMM1})\s*-\s*(#{YYYYMMDDHHMM1})$/) ||
            str.match(/^(#{YYYYMMDDHHMM2})\s*-\s*(#{YYYYMMDDHHMM2})$/) ||
            str.match(/^(#{YYYYMMDDHHMM3})\s*-\s*(#{YYYYMMDDHHMM3})$/)
    return unless match
    from = strip_time(match[1]) + "00 UTC"
    to   = strip_time(match[2]) + "59 UTC"
    from = DateTime.parse(from)
    to   = DateTime.parse(to)
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmddhh_x2(str)
    match = str.match(/^(#{YYYYMMDDHH1})\s*-\s*(#{YYYYMMDDHH1})$/) ||
            str.match(/^(#{YYYYMMDDHH2})\s*-\s*(#{YYYYMMDDHH2})$/) ||
            str.match(/^(#{YYYYMMDDHH3})\s*-\s*(#{YYYYMMDDHH3})$/)
    return unless match
    from = strip_time(match[1]) + "0000 UTC"
    to   = strip_time(match[2]) + "5959 UTC"
    from = DateTime.parse(from)
    to   = DateTime.parse(to)
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmdd_x2(str)
    match = str.match(/^(#{YYYYMMDD1})\s*-\s*(#{YYYYMMDD1})$/) ||
            str.match(/^(#{YYYYMMDD2})\s*-\s*(#{YYYYMMDD2})$/) ||
            str.match(/^(#{YYYYMMDD3})\s*-\s*(#{YYYYMMDD3})$/)
    return unless match
    from = strip_time(match[1]) + "000000 UTC"
    to   = strip_time(match[2]) + "235959 UTC"
    from = DateTime.parse(from)
    to   = DateTime.parse(to)
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymm_x2(str)
    match = str.match(/^(#{YYYYMM1})\s*-\s*(#{YYYYMM1})$/) ||
            str.match(/^(#{YYYYMM2})\s*-\s*(#{YYYYMM2})$/) ||
            str.match(/^(#{YYYYMM3})\s*-\s*(#{YYYYMM3})$/)
    return unless match
    from = strip_time(match[1]) + "01"
    to   = strip_time(match[2]) + "01"
    to   = Date.parse(to).next_month.prev_day.to_s
    to   = strip_time(to)
    from = DateTime.parse(from + "000000 UTC")
    to   = DateTime.parse(to + "235959 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyy_x2(str)
    match = str.match(/^(#{YYYY})\s*-\s*(#{YYYY})$/)
    return unless match
    from = strip_time(match[1]) + "0101000000 UTC"
    to   = strip_time(match[2]) + "1231235959 UTC"
    from = DateTime.parse(from)
    to   = DateTime.parse(to)
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmddhhmmss(str)
    match = str.match(/^#{YYYYMMDDHHMMSS1}$/) ||
            str.match(/^#{YYYYMMDDHHMMSS2}$/) ||
            str.match(/^#{YYYYMMDDHHMMSS3}$/)
    return unless match
    str  = strip_time(str) + " UTC"
    time = DateTime.parse(str)
    OrderedRange.new(time, time)
  end

  def parse_time_range_yyyymmddhhmm(str)
    match = str.match(/^#{YYYYMMDDHHMM1}$/) ||
            str.match(/^#{YYYYMMDDHHMM2}$/) ||
            str.match(/^#{YYYYMMDDHHMM3}$/)
    return unless match
    str  = strip_time(str)
    from = DateTime.parse(str + "00 UTC")
    to   = DateTime.parse(str + "59 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmddhh(str)
    match = str.match(/^#{YYYYMMDDHH1}$/) ||
            str.match(/^#{YYYYMMDDHH2}$/) ||
            str.match(/^#{YYYYMMDDHH3}$/)
    return unless match
    str  = strip_time(str)
    from = DateTime.parse(str + "0000 UTC")
    to   = DateTime.parse(str + "5959 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymmdd(str)
    match = str.match(/^#{YYYYMMDD1}$/) ||
            str.match(/^#{YYYYMMDD2}$/) ||
            str.match(/^#{YYYYMMDD3}$/)
    return unless match
    str  = strip_time(str)
    from = DateTime.parse(str + "000000 UTC")
    to   = DateTime.parse(str + "235959 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyymm(str)
    match = str.match(/^#{YYYYMM1}$/) ||
            str.match(/^#{YYYYMM2}$/) ||
            str.match(/^#{YYYYMM3}$/)
    return unless match
    str  = strip_time(str) + "01"
    str2 = Date.parse(str).next_month.prev_day.to_s
    str2 = strip_time(str2)
    from = DateTime.parse(str + "000000 UTC")
    to   = DateTime.parse(str2 + "235959 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_range_yyyy(str)
    match = str.match(/^#{YYYY}$/)
    return unless match
    str  = strip_time(str)
    from = DateTime.parse(str + "0101000000 UTC")
    to   = DateTime.parse(str + "1231235959 UTC")
    OrderedRange.new(from, to)
  end

  def parse_time_yyyymmddhhmmss(str)
    match = str.match(/^#{YYYYMMDDHHMMSS1}$/) ||
            str.match(/^#{YYYYMMDDHHMMSS2}$/) ||
            str.match(/^#{YYYYMMDDHHMMSS3}$/)
    raise ArgumentError unless match
    str = strip_time(str) + " UTC"
    DateTime.parse(str)
  end
end
