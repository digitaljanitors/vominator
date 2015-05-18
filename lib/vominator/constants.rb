require 'vominator/vominator'

LOGGER = Vominator::Logger

VOMINATOR_CONFIG = Vominator.get_config
PUKE_CONFIG = Vominator.get_puke_config(VOMINATOR_CONFIG['configuration_path'])

EC2_INSTANCE_METADATA = {
   :'t1.micro' => {:ephemeral_devices => 0, :virtualization_type => 'paravirtual'},
   :'t2.micro' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'t2.small' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'t2.medium' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'m1.small' => {:ephemeral_devices => 1, :virtualization_type => 'paravirtual'},
   :'m1.medium' => {:ephemeral_devices => 1, :virtualization_type => 'paravirtual'},
   :'m1.large' => {:ephemeral_devices => 2, :virtualization_type => 'paravirtual'},
   :'m1.xlarge' => {:ephemeral_devices => 4, :virtualization_type => 'paravirtual'},
   :'m3.medium' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'m3.large' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'m3.xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'m3.2xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c1.medium' => {:ephemeral_devices => 1, :virtualization_type => 'paravirtual'},
   :'c1.xlarge' => {:ephemeral_devices => 4, :virtualization_type => 'paravirtual'},
   :'m2.xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'paravirtual'},
   :'m2.2xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'paravirtual'},
   :'m2.4xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'paravirtual'},
   :'hi1.4xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'hs1.8xlarge' => {:ephemeral_devices => 24, :virtualization_type => 'hvm'},
   :'cr1.8xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'cc1.4xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'cc2.8xlarge' => {:ephemeral_devices => 4, :virtualization_type => 'hvm'},
   :'cg1.4xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c3.large' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c3.xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c3.2xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c3.4xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c3.8xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'c4.large' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'c4.xlarge' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'c4.2xlarge' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'c4.4xlarge' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'c4.8xlarge' => {:ephemeral_devices => 0, :virtualization_type => 'hvm'},
   :'g2.2xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'i2.xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'i2.2xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
   :'i2.4xlarge' => {:ephemeral_devices => 4, :virtualization_type => 'hvm'},
   :'i2.8xlarge' => {:ephemeral_devices => 8, :virtualization_type => 'hvm'},
   :'r3.large' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'r3.xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'r3.2xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'r3.4xlarge' => {:ephemeral_devices => 1, :virtualization_type => 'hvm'},
   :'r3.8xlarge' => {:ephemeral_devices => 2, :virtualization_type => 'hvm'},
}

