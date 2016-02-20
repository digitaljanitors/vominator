vominator_module = ARGV[1] || nil

case vominator_module
when 'create'
  require_relative '../lib/vpc/create'
else
  puts 'Module not found. Currently supported modules are: create'
end
