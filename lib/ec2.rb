vominator_module = ARGV[1] || nil

case vominator_module
when 'instances'
  require_relative '../lib/ec2/instances'
when 'ssm'
  require_relative '../lib/ec2/ssm'
when 'security_groups'
  require_relative '../lib/ec2/security_groups'
else
  puts 'Module not found. Currently supported modules are: instances, ssm, security_groups'
end
