$stdout.sync = true

Process.kill(:INT, ARGV[1].to_i)
puts "killed #{ARGV[1]}"