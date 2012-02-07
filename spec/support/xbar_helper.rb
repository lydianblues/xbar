def clean_all_shards
  if proxy = Thread.current[:connection_proxy]
    tables = ['schema_migrations', 'users', 'clients', 'cats', 'items', 'keyboards',
      'computers', 'permissions_roles', 'roles', 'permissions', 'assignments',
      'projects', 'programmers', "yummy"]
    proxy.shards.keys.each do |key|
      tables.each do |t|
        BlankModel.using(key).connection.execute("DELETE FROM #{t}")
      end
    end
  end
end

def clean_connection_proxy
  Thread.current[:connection_proxy] = nil
end

def migrating_to_version(version, &block)
  puts "migrating to version called version = #{version}"
  ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT, version)
  yield
ensure
  ActiveRecord::Migrator.run(:down, MIGRATIONS_ROOT, version)
end

def using_environment(environment, &block)
  prev_env = XBar::Mapper.app_env
  XBar::Mapper.reset(xbar_env: 'default', app_env: environment.to_s)
  yield
ensure
  XBar::Mapper.reset(xbar_env: 'default', app_env: prev_env)
end

def set_xbar_env(xbar_env, app_env = nil)
  opts = {xbar_env: xbar_env.to_s, :clear_cache => true}
  if app_env && !defined?(Rails)
    opts[:app_env] = app_env.to_s
  end
  XBar::Mapper.reset(opts)
  # Not needed because reset should clean, I think.  
  #Thread.current[:connection_proxy].clean_proxy if Thread.current[:connection_proxy]
end
