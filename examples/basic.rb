require File.expand_path(File.join(File.dirname(__FILE__),  'lib/setup'))

module Examples
  Setup.start('simple', 'test', 1)

  # Define the model to let us access the 'users' table through ActiveRecord.
  class User < ActiveRecord::Base; end

  # Everything is now set up. Remember that the three store shards don't 
  # really replicate.  XBar is set up to *think* that they do.  We know
  # better, and can check that reads and writes go to the shards that 
  # we think that they should.  The curious results below wouldn't happen
  # if replication is really taking place (modulo the eventual-consistency
  # problem).

  User.using(:bakery).create!([{name: "mudpie"}, {name: "hohos"}])
  XBar.using(:deli) do
    User.create!([{name: "pastrami"}, {name: "potato salad"}, {name: "pizza"}])
  end
  User.using(:store).create!(name: "safeway")

  s1 = User.using_any(:store).all.size # reads 'bakery', gets 2
  s2 = User.using_any(:store).all.size # reads 'deli', gets 3
  s3 = User.using_any(:store).all.size # reads 'bakery', gets 2
  s4 = User.using_any(:store).all.size # reads 'deli', gets 2
  p1 = User.using(:produce).all.size # 1
  b1 = User.using(:bakery).all.size # 2
  d1 = User.using(:deli).all.size # 3

  puts [s1, s2, s3, s4, p1, b1, d1].to_s # [2, 3, 2, 3, 1, 2, 3]

  Setup.stop(1)
end

