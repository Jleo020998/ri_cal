require 'date'
module RiCal
  class PropertyValue
    class DateTime < PropertyValue

      def self.debug
        @debug
      end

      def self.default_tzid
        @default_tzid ||= "UTC"
      end

      def self.default_tzid=(value)
        @default_tzid = value
      end

      def self.default_tzid_hash
        if default_tzid.to_s == 'none'
          {}
        else
          {'TZID' => default_tzid}
        end
      end

      def self.debug= val
        @debug = val
      end

      include Comparable

      def self.from_separated_line(line)
        if /T/.match(line[:value] || "")
          new(line)
        else
          PropertyValue::Date.new(line)
        end
      end

      def to_ri_cal_date_time_value
        self
      end

      def duration_until(end_time)
        #TODO: this should calculate a duration
        #  if end_time is nil => nil
        #  otherwise convert end_time to a DateTime and compute the difference
        end_time  && RiCal::PropertyValue::Duration.from_datetimes(to_datetime, end_time.to_datetime)
      end

      def subtract_from_date_time_value(dtvalue)
        RiCal::PropertyValue::Duration.from_datetimes(to_datetime,dtvalue.to_datetime)
      end

      def add_to_date_time_value(date_time_value)
        raise ArgumentError.new("Cannot add #{date_time_value} to #{self}")
      end

      def -(other)
        other.subtract_from_date_time_value(self)
      end

      def +(other)
        other.add_to_date_time_value(self)
      end

      def to_s
        "ri_cal:#{@value}"
      end

      def inspect
        "ri_cal:#{@value}::#{@date_time_value}#{params ? " #{params.inspect}" : ""}"
      end

      def value
        if @date_time_value
          @date_time_value.strftime("%Y%m%dT%H%M%S#{tzid == "UTC" ? "Z" : ""}")
        else
          nil
        end
      end 

      def value=(val)
        case val
        when nil
          @date_time_value = nil
        when String
          @params['TZID'] = 'UTC' if val =~/Z/
          @date_time_value = ::DateTime.parse(val)
        when ::DateTime
          @date_time_value = val
        end
      end

      # determine if the object acts like an activesupport enhanced time, and return it's timezone if it has one.
      def self.object_time_zone(object)
        activesupport_time = object.acts_like_time? rescue nil
        activesupport_time && object.time_zone rescue nil
      end

      def self.convert(ruby_object)
        time_zone = object_time_zone(ruby_object)
        if time_zone
          new(
          :params => {'TZID' => time_zone.identifier, 'X-RICAL-TZSOURCE' => 'TZINFO'}, 
          :value => ruby_object.strftime("%Y%m%d%H%M%S")
          )
        else
          ruby_object.to_ri_cal_date_time_value
        end
      end

      def self.from_string(string)
        new(:value => string, :params => default_tzid_hash)
      end

      def self.from_time(time_or_date_time)
        time_zone = object_time_zone(time_or_date_time)
        if time_zone
          new(
          :params => {'TZID' => time_zone.identifier, 'X-RICAL-TZSOURCE' => 'TZINFO'}, 
          :value => time_or_date_time.strftime("%Y%m%d%H%M%S")
          )
        else
          new(:value => time_or_date_time.strftime("%Y%m%dT%H%M%S"), :params => default_tzid_hash)
        end
      end

      def tzid
        params && params['TZID']
      end

      def to_datetime
        @date_time_value
      end
      
      def to_ruby_value
        to_datetime
      end

      alias_method :ruby_value, :to_datetime

      def compute_change(d, options)
        ::DateTime.civil(
        options[:year]  || d.year,
        options[:month] || d.month,
        options[:day]   || d.day,
        options[:hour]  || d.hour,
        options[:min]   || (options[:hour] ? 0 : d.min),
        options[:sec]   || ((options[:hour] || options[:min]) ? 0 : d.sec),
        options[:offset]  || d.offset,
        options[:start]  || d.start
        )
      end

      def compute_advance(d, options)
        d = d >> options[:years] * 12 if options[:years]
        d = d >> options[:months]     if options[:months]
        d = d +  options[:weeks] * 7  if options[:weeks]
        d = d +  options[:days]       if options[:days]
        datetime_advanced_by_date = compute_change(@date_time_value, :year => d.year, :month => d.month, :day => d.day)
        seconds_to_advance = (options[:seconds] || 0) + (options[:minutes] || 0) * 60 + (options[:hours] || 0) * 3600
        seconds_to_advance == 0 ? datetime_advanced_by_date : datetime_advanced_by_date + Rational(seconds_to_advance.round, 86400)
      end

      def advance(options)
        PropertyValue::DateTime.new(:value => compute_advance(@date_time_value, options), :params =>(params ? params.dup : nil) )
      end

      def change(options)
        PropertyValue::DateTime.new(:value => compute_change(@date_time_value, options), :params => (params ? params.dup : nil) )
      end

      def <=>(other)
        @date_time_value <=> other.to_datetime
      end

      def ==(other)
        if self.class === other
          self.value == other.value && self.params == other.params
        else
          super
        end
      end

      # TODO: consider if this should be a period rather than a hash    
      def occurrence_hash(default_duration)
        {:start => self, :end => (default_duration ? self + default_duration : nil)}
      end

      def method_missing(selector, *args)
        @date_time_value.send(selector, *args)
      end
    end
  end
end