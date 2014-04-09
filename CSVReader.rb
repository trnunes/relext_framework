f = File.open("repository_production-examples-full.csv", "r")
f2 = File.open("repository_production-examples-100.csv", "w")
i = 0
f.each_line do |line|
  f2.puts line
  i += 1
  break if i == 100
end
f.close