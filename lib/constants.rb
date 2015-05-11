require './vominator.rb'

VOMINATOR_CONFIG = Vominator.get_config
PUKE_CONFIG = Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])
