require './vominator.rb'

LOGGER = Logger.new(STDOUT)

VOMINATOR_CONFIG = Vominator.get_config
PUKE_CONFIG = Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])
