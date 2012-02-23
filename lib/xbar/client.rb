require 'net/http'

module XBar
  module Client
    #
    # Send a new JSON configuration document to the mapper and reset the
    # mapper.  The JSON document can be passed either by using the 
    # <tt>:file</tt>option to specify the name of a file containing the
    # JSON document, or the document can be passed as a string, using the
    # <tt>:data</tt> option.  The <tt>:xbar_env</tt> option is required 
    # to name the XBar environment.  The <tt>:app_env</tt> option is 
    # optional -- it defaults to the current app_env.  In either case,
    # it should be the name of an environment stanza in the JSON document.
    # 
    def reset(host, port, opts)
      xbar_env = opts[:xbar_env]
      app_env = opts[:app_env]
      
      path = "/reset/#{xbar_env}"
      path += "/#{app_env}" if app_env
      uri = URI::HTTP.build(host: host, port: port, path: path)

      if opts.has_key? :data
        data = opts[:data]
      elsif opts.has_key? :file
        data = ''
        File.open(opts[:file], "r") do |f|
          data = f.read
        end
      else
        data = nil
      end
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.post(uri.path, data, "Content-Type" => "application/json")
    end

    # Return the current XBar environment as JSON document contained in a string.
    def config(host, port)
      uri = URI::HTTP.build(host: host, port: port, path: '/config')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.get(uri.path, "Accept" => "application/json")
    end

    # Get the current <tt>xbar_env</tt>, <tt>app_env</tt>, and 
    # <tt>rails_env</tt> as a JSON document.
    def environments(host, port)
      uri = URI::HTTP.build(host: host, port: port, path: '/environments')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.get(uri.path, "Accept" => "application/json")
    end

    # Pause, wait, or resume processing at all proxies according to
    # <tt>opts[:cmd]</tt>.  If the <tt>cmd</tt> is not specified then
    # the current runstate is queried.
    def runstate(host, port, opts = {})
      cmd = opts[:cmd]
      if [:pause, :wait, :resume].include?(cmd.to_sym)
        path = "/runstate/#{cmd.to_s}"
      else
        path = "/runstate/query"
      end

      uri = URI::HTTP.build(host: host, port: port, path: path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.get(uri.path, "Accept" => "application/json")
    end

  end
end        

