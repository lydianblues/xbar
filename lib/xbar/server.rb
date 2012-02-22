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

    cert = OpenSSL::X509::Certificate.new File.read CERTIFICATE
    pkey = OpenSSL::PKey::RSA.new File.read PRIVATE_KEY

    log = File.open('/tmp/xbar-access-log', 'a')
    access_log = [
      [log, WEBrick::AccessLog::COMMON_LOG_FORMAT],
      [log, WEBrick::AccessLog::REFERER_LOG_FORMAT],
    ]
    @logger = Logger.new('/tmp/xbar-logger', shift_age = 7, shift_size = 1048576)

    @server = WEBrick::HTTPServer.new(Port: PORT,
                                      AccessLog: access_log,
                                      Logger: @logger,
                                      SSLEnable: true,
                                      SSLCertificate: cert,
                                      SSLPrivateKey: pkey)
    # Use this instead for NO SECURITY.
    # server = WEBrick::HTTPServer.new(Port: PORT)

    def self.start
      @logger.info "Starting XBar Server"
      @server.start
    end

    def self.shutdown
      @logger.info "Shutting down XBar Server"
      @server.shutdown
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
          puts "xbar_env = #{xbar_env}"
          puts "app_env = #{app_env}"
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
        puts "Resetting XBar::Mapper with params #{params}"
        # XBar::Mapper.reset(params)
      end
    end

    class Shutdown < WEBrick::HTTPServlet::AbstractServlet
      def do_POST(request, response)
        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = 'Shutting down'
        XBar::Server.shutdown
      end
    end

    @server.mount '/reset', Reset
    @server.mount '/shutdown', Shutdown

  end
end


