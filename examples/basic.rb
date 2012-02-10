require File.expand_path(File.join(File.dirname(__FILE__),  'setup'))

module Examples
  Setup.start('simple', 'test', 1)

  # Define the model to let us access the 'users' table through ActiveRecord.
  class User < ActiveRecord::Base; end

  # Everything is now set up. Remember that the three french shards don't 
  # really replicate.  XBar is set up to *think* that they do.  We know
  # better, and can check that reads and writes go to the shards that 
  # we think that they should.  They curious results below wouldn't happen
  # if replication is really taking place (modulo the eventual-consistency
  # problem).

  User.using(:france_central).create!([{name: "central1"}, {name: "central2"}])
  XBar.using(:france_sud) do
    User.create!([{name: "sud1"}, {name: "sud2"}, {name: "sud3"}])
  end
  User.using(:france).create!(name: "nord1")

  f1 = User.using(:france).all.size # 2
  f2 = User.using(:france).all.size # 3
  f3 = User.using(:france).all.size # 2
  f4 = User.using(:france).all.size # 3
  n1 = User.using(:france_nord).all.size # 1
  c1 = User.using(:france_central).all.size # 2
  s1 = User.using(:france_sud).all.size # 3

  puts [f1, f2, f3, f4, n1, c1, s1].to_s # [2, 3, 2, 3, 1, 2, 3]

  Setup.stop(1)
end

