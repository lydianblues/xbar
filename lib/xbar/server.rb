require 'webrick'
require 'webrick/https'
require 'openssl'

require 'json'
require 'erb'

# To test with curl:
#
# curl -k -H "Content-Type: application/json" -d '{"screencast":{"subject":"tools"}}' \
#   https://localhost:7250/reset
#
# Or to post the JSON reset config from a file:
#
# curl -k -H "Content-Type: application/json" -d '@../../examples/config/canada.json' \
#   https://localhost:7250/reset

module XBar
  module Server

    CERTDIR = File.expand_path(File.join(File.dirname(__FILE__), "../../certs"))
    CERTIFICATE = File.join(CERTDIR, "xbar.crt")
    PRIVATE_KEY = File.join(CERTDIR, "xbar.key")
    PORT = 7250

    def self.start
      cert = OpenSSL::X509::Certificate.new File.read CERTIFICATE
      pkey = OpenSSL::PKey::RSA.new File.read PRIVATE_KEY

      @log = File.open('/tmp/xbar-access-log', 'a')
      @logger ||= Logger.new('/tmp/xbar-logger', shift_age = 7,
        shift_size = 1048576)

      access_log = [
        [@log, WEBrick::AccessLog::COMMON_LOG_FORMAT],
        [@log, WEBrick::AccessLog::REFERER_LOG_FORMAT],
      ]
      @server = WEBrick::HTTPServer.new(Port: PORT,
        AccessLog: access_log, Logger: @logger, SSLEnable: true,
        SSLCertificate: cert, SSLPrivateKey: pkey)

      @logger.info "Starting XBar Server."
      @server.mount '/reset', Reset
      @server.mount '/config', Config
      @server.mount '/environments', Environments
      @server.mount '/runstate', RunState
      @server.start
      XBar.logger.info "XBar start returned."
    end

    def self.wait_until_ready(timeout = 10)
      retries = 2 * timeout
      retries.times do
        break if @server
        sleep 0.5
      end 
      return !!@server
    end

    def self.shutdown
      @logger.info "Shutting down XBar Server."
      if wait_until_ready
        @server.shutdown
        @log.close
        @server = nil # for garbage collector
      end
    end

    class Reset < WEBrick::HTTPServlet::AbstractServlet
      def do_GET(request, response)
        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = 'Hello, World!'
      end

      # The 
      def do_POST(request, response)
        error = false
    not_json = <<-"_RESPONSE_"
    <!DOCTYPE html>
    <html lang="en">
      <meta <meta charset="utf-8">
      <head><title>Invalid Content-Type Header</title></head>
      <body>
        <h1>Mime content-type must be "application/json"</h1>
          Send a valid JSON document with content-type header "application/json"
        <hr>
        <address>
         #{request.meta_vars["SERVER_SOFTWARE"]} at
         #{request.meta_vars["SERVER_NAME"]}:#{request.meta_vars["SERVER_PORT"]}
        </address>
      </body>
    </html>
    _RESPONSE_

    invalid_json = <<-"_RESPONSE_"
    <!DOCTYPE html>
    <html lang="en">
      <meta <meta charset="utf-8">
      <head><title>JSON document is Invalid</title></head>
      <body>
        <h1>JSON document is invalid"</h1>
          JSON configuration specification did not parse correctly.
        <hr>
        <address>
         #{request.meta_vars["SERVER_SOFTWARE"]} at
         #{request.meta_vars["SERVER_NAME"]}:#{request.meta_vars["SERVER_PORT"]}
        </address>
      </body>
    </html>
    _RESPONSE_

    invalid_uri = <<-"_RESPONSE_"
    <!DOCTYPE html>
    <html lang="en">
      <meta <meta charset="utf-8">
      <head><title>Invalid format for reset URI</title></head>
      <body>
        <h1>Invalid format for reset URI"</h1>
          URI must has the form: "https://<host>:<port>/reset/<xbar_env>/[<app_env>]".
          The "app_env" may be omitted.  In this case, the current app_env is used.
        <hr>
        <address>
         #{request.meta_vars["SERVER_SOFTWARE"]} at
         #{request.meta_vars["SERVER_NAME"]}:#{request.meta_vars["SERVER_PORT"]}
        </address>
      </body>
    </html>
    _RESPONSE_

        if request.content_type != "application/json"
          response.status = 400 #XXX
          response.body = not_json
          response.content_type = "text/html"
          error = true
        end
        
        # URL has the form: "https://<host>:<port>/reset/<xbar_env>/<app_env>"
        # If app_env is omitted, XBar::Reset will use its current
        # app_env.
        unless error
          envs = request.meta_vars["PATH_INFO"].split('/').delete_if {|e| e.length == 0}
          xbar_env = envs.shift
          app_env = envs.shift
          unless xbar_env
            response.body = invalid_uri
            response.status = 400 #XXX
            response.content_type = "text/html"
            error = true
          end
        end

        unless error
          begin
            config = JSON.parse(ERB.new(request.body).result)
          rescue JSON::ParserError
            response.body = invalid_json
            response.status = 400 #XXX
            response.content_type = "text/html"
          else
            response.status = 200
            response['Content-Type'] = 'text/plain'
          end
        end

        params = {config: config, xbar_env: xbar_env}
        params[:app_env] = app_env if app_env
        XBar::Mapper.reset(params)
      end
    end

    # Get the current JSON document.
    class Config < WEBrick::HTTPServlet::AbstractServlet
      def do_GET(request, response)
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = XBar::Mapper.config.to_json
      end
    end

    # Handle runstates: pause, wait, resume.  Also query.
    class RunState < WEBrick::HTTPServlet::AbstractServlet
      def do_GET(request, response)
        cmd = request.meta_vars["PATH_INFO"][1..-1] # remove leading '/'
        case cmd
        when 'pause'
          XBar::Mapper.request_pause
          resp = "OK"
        when 'wait'
          XBar::Mapper.wait_for_pause
          resp = "OK"
        when 'resume'
          XBar::Mapper.unpause
          resp = "OK"
        when 'query'
          count = XBar::Mapper.pause_count
          resp = count.to_s
        else
          resp = "Unknown command #{cmd}"
        end
        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = resp
      end
    end

    # Get the current environments.
    class Environments < WEBrick::HTTPServlet::AbstractServlet
      def do_GET(request, response)
        response.status = 200
        response['Content-Type'] = 'application/json'

response.body = <<-"_EOT_"
{
  \"app_env\": \"#{XBar::Mapper.app_env}\",
  \"xbar_env\": \"#{XBar::Mapper.xbar_env}\",
  \"rails_env\": \"#{XBar.rails_env}\"
}
_EOT_

      end
    end
  end
end


