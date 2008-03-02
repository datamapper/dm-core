#!/opt/local/bin/ruby

require 'environment'
require 'ruby-prof'

# RubyProf, making profiling Ruby pretty since 1899!
def profile(&b)
  result = RubyProf.profile &b

  printer = RubyProf::GraphHtmlPrinter.new(result)
  File::open('profile_results.html', 'w+') do |file|
    printer.print(file, 0)
  end
end

profile do
  1000.times do
    Zoo.all.each { |zoo| zoo.name; zoo.exhibits.entries }
  end
end

puts "Done!"

# require 'benchmark'
# 
# N = 100_000
# 
# Benchmark::bmbm do |x|
#   x.report do
#     N.times do
#       Inflector.underscore('DataMapper')
#     end    
#   end
# 
#   x.report do
#     N.times do
#       String::memoized_underscore('DataMapper')
#     end
#   end
# end