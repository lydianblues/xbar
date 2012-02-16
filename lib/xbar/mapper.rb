module XBar
  #
  # This module holds the current configuration. It is read from a JSON document
  # and always represents exactly the state of that document. The configuration
  # should not be 'tweaked' by changing the state of in-memory structures.  The
  # approved way to change the configuration is to call:
  #
  #     XBar::Mapper.reset(:xbar_env => "<config file>",
  #       :app_env => "<application environment>")
  # 
  # This loads a new configuration file from the XBar 'config' directory.
  # This file may contain multiple 'environments'.  Only the specified
  # environment is used.  Both arguments are required.  Changes to the
  # configuration via this API cause all Proxies and their Shards to be reset.
  # This is, all Proxies are found and 'cleaned', and the Shard references held
  # by each Proxy are dropped and new Shards are allocated.
  #
  # No thread-specific state is kept in the Mapper structure. In fact, the state
  # it encapsulates is shared by all threads.  In contrast, thread-specific
  # state is kept in instances of the Proxy class, or instances of the Shard
  # class.  Thread specific state is handled as follows:
  #
  # Thread.current[:connection_proxy] references an instance of Proxy.
  # In turn, an an instance of XBar::Proxy references a list of instances of
  # XBar::Shard.
  #
  # Each Shard is considered to be an array of replicas, even if the
  # configuration JSON specifies a single Connection (as a String literal).  In
  # this case, the Shard is an array of one replica.  At any point in time, each
  # Shard has one replica designated as the master.  Thus the complete Shard
  # description always an array of Connections and the first Connection in the
  # array is considered to be the master.
  #
  # This module is included in the XBar::Proxy class.  This adds instance
  # methods to instances of XBar::Proxy that allow the configuration state to
  # be read.
  #
  # The following data structures are maintained:
  #
  #     @@connections -- a Hash, the key is the connection name and the value
  #       is a connection pool.
  #     @@shards -- an array of Hashes.  For each hash the key is the shard name
  #       and the value is a connection pool.
  #
  module Mapper
    
    def self.exports
      # omit master_config
      %w(connections shards adapters options app_env proxies).map(&:to_sym)
    end
    
    module ClassMethods
      
      Mapper.exports.each do |var|
        mattr_reader var
      end
      
      @@cached_config = nil
      @@shards = HashWithIndifferentAccess.new
      @@connections = HashWithIndifferentAccess.new
      @@proxies = {}
      @@adapters = Set.new
      @@config = nil
      @@app_env = nil
      @@xbar_env = nil
        
      def config_file_name
        file = "#{xbar_env}.json"
        "#{XBar.directory}/config/#{file}"
      end
      
      def connection_file_name
        file = "connection.rb"
        "#{XBar.directory}/config/#{file}"
      end

      def config_from_file
        file_name = config_file_name
       
        if File.exists? file_name
          if XBar.debug
            puts "XBar::Mapper, reading configuration from file #{file_name}"
          end
          config = JSON.parse(ERB.new(File.read(file_name)).result)
        else
          if XBar.debug
            puts("XBar::Mapper: No config file #{file_name} -- " +
                 "Deriving defaults.")
          end
          config = {}
        end
        HashWithIndifferentAccess.new(config)
      end
      
      def config
       @@cached_config ||= config_from_file
      end 
      
      # Alter the configuration in-memory for the current XBar envirnoment.
      def shards=(shards)
        cached_config["environments"][app_env] = shards
      end
       
      # This needs to be reconciled with the 'environments' method in the
      # XBar module.  That method specifies the environments that XBar should
      # be enabled for.  The present method returns the environments that
      # the current config file contains. XXX
      def environments
        config['environments'].keys
      end
       
      #
      # When we switch the XBar env or the Rails env (either of which
      # changes the set of available shards, we have to find all the
      # connection proxies and reset their current shard to :master.)
      #
      # Q1.  Are all the connection proxies pointed to by model classes
      # findable through Thread.current[:connection_proxy]?  We'll have
      # to loop over all threads. XXX
      #
      # Alternatively, we can register each XBar::Proxy.new call to
      # a hash in the XBar module.
      #
      def reset(options = {})
        new_xbar_env = options[:xbar_env] || xbar_env
        if (new_xbar_env != xbar_env) || (options[:clear_cache]) ||
          (!@@cached_config.nil? && @@cached_config.empty?)
          @@cached_config = nil
        end
        self.xbar_env = new_xbar_env
        self.app_env = options[:app_env] if options[:app_env]
            
        if XBar.debug
          puts "XBar::Mapper#reset, xbar_env=#{xbar_env}, app_env=#{app_env}"
        end
        initialize_shards(config)
        initialize_options(config)
        
        # If Rails or some other entity has not assigned a native connection
        # for ActiveRecord, we will try to do something sensible.  This is only
        # needed if you have some enviroments for which XBar is not enabled. 
        # However, it's not likely you'll want to enable XBar for only some
        # environments.  (What would be a use case?)  The first 
        # choice is that if we have a shard called 'master', we will use its
        # connection specification.  The second choice is to include a Ruby
        # file that contains a call to 'establish connection'.  In this case,
        # we will create a shard called master with the same connection 
        # specification.  Thus there will always be a 'master' shard.
        #
        # Also, there is the case where there is a connection, but the config
        # document didn't specify a master shard.  
        
        begin
          connection_pool = ActiveRecord::Base.connection_pool_without_xbar
        rescue
          if @@shards.keys.include? "master"
             ActiveRecord::Base.establish_connection(
               XBar::Mapper.shards[:master][0].spec.config)
          else
            # The config file didn't exist or didn't specify a master shard. Or
            # app_env wasn't specified (as an argument option).
            require connection_file_name
            connection_pool = ActiveRecord::Base.connection_pool_without_xbar
          end  
        end
        if !@@shards.keys.include?("master") && connection_pool
          @@shards[:master] = Array(connection_pool)
          @@adapters << connection_pool.spec.config
        end
        
        @@proxies.values.each do |proxy|
          proxy.request_reset
        end

        self
      end
      
      def initialize_options(aconfig)
        @@options = aconfig["environments"][app_env].dup
        @@options.delete("shards")
      rescue
        @@options = {}
      ensure
        @@options[:verify_connection] ||= false
      end
      
      # Register a proxy on behalf of the current thread.
      def register(proxy)
	reset if shards.empty?
        @@proxies[Thread.current.object_id] = proxy
      end

      # Unregister the proxy for the current thread, or for the specified
      # thread.  A thread can be specified by passing a Thread instance or
      # its object_id.
      def unregister(thread_spec = Thread.current)
        thread_spec = thread_spec.object_id if thread_spec.instance_of?(Thread)
        XBar::Mapper.proxies.delete(thread_spec)
      end

      def disconnect_all!
        shards.each do |name, pool_list|
          pool_list.each_with_index do |p, i|
            if p.connected?
              puts "shard=#{name}, object_id=#{p.object_id}, connections = #{p.connections.size}"
              p.disconnect!
            end
          end
        end
      end
      
      def app_env
        @@app_env = XBar.rails_env || @@app_env
      end

      def xbar_env
        @env ||= 'default'
      end
      
      private
      
      def app_env=(env)
        if XBar.rails_env && XBar.rails_env != env
          raise XBar::ConfigError, "Can't change app_env when you have a Rails environment."
        end
        @@app_env = env
      end 

      # When XBar::Mapper is processing a reset, it will call this method.  No other
      # method should call this.
      def xbar_env=(xbar_env)
        @env = xbar_env
      end
      
      def initialize_shards(aconfig)
       
        # The way this works right now, if the same adapter spec is used 
        # in multiple shards, we will get multiple connection pools
        # initialized with the same spec.  It might be better to share
        # connection pools among the shards.

        @@connections.clear
        @@adapters.clear
        @@shards.clear
        pool_for_spec = {}
        
        if aconfig
          begin
            shards_config = aconfig["environments"][app_env]["shards"]
          rescue
            shards_config = nil
          end
        end
        shards_config ||= []
        shards_config.delete_if {|k| k == "__COMMENT"}
        
        shards_config.each do |shard_key, connection_key|
          if @@shards.include? shard_key 
            raise ConfigError, "You have duplicate shard names!"
          end
          if connection_key.kind_of? String
            spec = aconfig["connections"][connection_key]
            unless pool = pool_for_spec(spec)
              pool = install_connection(connection_key, spec)
              pool_for_spec[spec] = pool
            end
            @@shards[shard_key] = [pool]
          else # an array of connection keys
            @@shards[shard_key] = []
            connection_key.each do |conn_key|
              spec = aconfig["connections"][conn_key]
              unless pool = pool_for_spec(spec)
                pool = install_connection(conn_key, spec)
                pool_for_spec[spec] = pool
              end
            end
              @@shards[shard_key] << pool
            end
          end
        end
      end
      
      # Should return a ConnectionPool.
      def install_connection(conn_key, spec)
        unless spec
          raise XBar::ConfigError, "No connection for key #{conn_key}"
        end
        if defined? ActiveRecord::Base::ConnectionSpecification::Resolver
          resolver = ActiveRecord::Base::ConnectionSpecification::Resolver.new(spec, {})
          spec = resolver.spec
          @@adapters << spec.config[:adapter]
          @@connections[conn_key.to_sym] = 
            ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec)
        else
          old_install_connection(conn_key, spec)
        end
      end
      
      def old_install_connection(conn_key, spec)
        unless spec
           raise XBar::ConfigError, "No connection for key #{conn_key}"
         end
        install_adapter(spec['adapter'])
        @@connections[conn_key.to_sym] =
          connection_pool_for(spec, "#{spec['adapter']}_connection")  
      end
      
      # Called only from 'old_install_connection'.  If you get here, you should not
      # be using connection URI's.
      def install_adapter(adapter)
        @@adapters << adapter
        begin
          require "active_record/connection_adapters/#{adapter}_adapter"
        rescue LoadError
          raise "Please install the #{adapter} adapter: " +
            "`gem install activerecord-#{adapter}-adapter` (#{$!})"
         end
      end
      
      def connection_pool_for(adapter, spec)
        ActiveRecord::ConnectionAdapters::ConnectionPool.new(
          ActiveRecord::Base::ConnectionSpecification.new(adapter, spec))
      end
    end
    
    # Give module XBar::Mapper the above class methods.
    self.extend(ClassMethods)
    
    Mapper.exports.each do |meth|
      define_method(meth) {Mapper.send(meth)}
    end
    
    def reset_config(options = {})
      Mapper.reset(options)
    end
    
    def register
      Mapper.register(self)
    end
  
  end
  
end
