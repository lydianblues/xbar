require "logger"

class XBar::Logger < Logger
  def format_message(severity, timestamp, progname, msg)
    str = super

    if proxy = Thread.current[:connection_proxy]
      str += "Shard: #{proxy.current_shard} -"
    end

    str
  end
end

