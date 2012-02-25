# This is the simplest possible way to start up an XBar configuration server.
# As soon as you require 'xbar', the server will start.  This server is meant
# for testing with 'client.rb', also in this directory.  The only extra feature
# is the trap of SIGUSR1, so that the client can make the server exit.  The
# reason that we're not simply using SIGKILL is that eventually we may want to
# do more work in the signal handler.

Signal.trap("SIGUSR1") { puts "Exit via SIGUSR1!"; STDOUT.flush; exit(0) }

require 'active_record'
require 'xbar'

sleep 60 * 60
