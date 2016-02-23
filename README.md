# Vominator


**NOTE** This is still in development, and for now depends on VPCs and such being setup by Vominator from the start. Documentation is still a WIP but the below should be enough to get someone going.

A CLI utility for managing AWS resources from yaml templates. This allow you to define resources within a dev VPC, and replicate that to a QA/Staging/Prod VPC without any additional work.

This CLI utility expects that your VPCs are setup in a specific way. You should use this tool to create a new VPC before launching resources into it.

This CLI utility will require you to define resources via YAML files. This should be kept in a repo of yours. You can see https://github.com/digitaljanitors/sample-puke for a reference.


## Installation

See Usage for details about puke

1. `$ gem install vominator`
2. Create ~/.vominator.yaml
```
---
access_key_id: AWS_SECRET_KEY
secret_access_key: AWS_SECRET_ACCESS_KEY
configuration_path: Location to puke
key_pair_name: infrastructure@example.com
```
## Usage

Everything with Vominator revolves around the concept of defining products. These products are a logical grouping of resources that describe how your product is deployed and accessed. These products are then associated with an environment so that you can quickly replicate resources between VPCs.

You will want to create a directory somewhere on your file system that contains your "puke". This is the code that describes how your environment should be built. You can see an example repo here: https://github.com/digitaljanitors/sample-puke

```
├── config.yaml
└── products
    └── sample-api
        ├── instances.yaml
        └── security_groups.yaml
```

In short, under products you create a directory for each new product. Most likely you will have a base product that gets associated to every VPC. You would then create an instances.yaml and security_groups.yaml file that describes everything you want as your base. This would generally be a jumpbox and/or VPN server, and possibly groups such as outbound-connections. config.yaml will be generated for you by vominator using the vpc creation command.

**This repo should be checked in to your own revision control system.**

### Creating your VPCs

Vominator should be used to bootstrap and build your VPCs that will be managed.

This will do the following...
* Create a VPC using the specified /16 network block within the specified region.
* Create a route53 zone equal to ${environment}.${parent-domain}. If we cannot find the parent domains zone file in route53 you will be prompted with the approriate details to configure your parent zone file.
* Create an IGW device

For each specified or auto detected availability zone for the account this will do several things...
* Create a public /24 subnet starting at 10.x.1.0/24
* Create a private /24 subnet started at 10.x.11.0/24
* Create a NAT gateway device for the AZ and configure a routing table for that zone.

Vominator will then output a block of YAML that can be put into your puke specific config.yaml.

```
$ vominate vpc create -h
Usage: vominate vpc create [options]
    -e, --environment ENVIRONMENT    REQUIRED: The environment which you want to create a VPC for. IE foo
        --region Region              REQUIRED: The AWS Region that you want to create the VPC in. IE us-east-1
        --availability-zones AVAILABILITY ZONES
                                     OPTIONAL: A comma delimited list of specific availability zones that you want to prepare. If you don't specify then we will use all that are available. IE us-east-1c,us-east-1d,us-east-1e
        --parent-domain PARENT DOMAIN
                                     REQUIRED: The parent domain name that will be used to create a seperate subdomain zone file for the new environment. IE, if you provide foo.org and your environment as bar, this will yield a new Route 53 zone file called bar.foo.org
        --cidr-block CIDR Block      REQUIRED: The network block for the new environment. This must be a /16 and the second octet should be unique for this environment. IE. 10.123.0.0/16
    -d, --debug                      OPTIONAL: debug output
    -h, --help                       OPTIONAL: Display this screen 
```

### Managing your security groups
Security groups get defined in your security_groups.yaml file for each product. You can reference the sample puke to get an idea of whats possible.

```
$ vominate ec2 security_groups -h
Usage: vominate ec2 security_groups [options]
    -p, --product PRODUCT            REQUIRED: The product which you want to manage security groups for
    -e, --environment ENVIRONMENT    REQUIRED: The environment which you want to manage security groups for
        --security-groups GROUPS     OPTIONAL: Comma Delimited list of security groups
        --delete                     Enable Deletions. This should be used with care
    -t, --test                       OPTIONAL: Test run. Show what would be changed without making any actual changes
    -l, --list                       OPTIONAL: List out products and environments
        --verbose                    OPTIONAL: Show all security group rules in tables
    -d, --debug                      OPTIONAL: debug output
    -h, --help                       OPTIONAL: Display this screen

```
### Managing your instances
Instances are managed in your instances.yaml file for each product. You can reference the sample puke to get an idea of whats possible.
```
$ vominate instances -h
Usage: vominate instance [options]
    -p, --product PRODUCT            REQUIRED: The product which you want to manage instances for
    -e, --environment ENVIRONMENT    REQUIRED: The environment which you want to manage instances for
    -s, --servers SERVERS            OPTIONAL: Comma Delimited list of servers that you want to manage instances for
    -t, --test                       OPTIONAL: Test run. Show what would be changed without making any actual changes
        --fix-security-groups        OPTIONAL: Fix an instances security groups
        --disable-term-protection    OPTIONAL: This will disable termination protection on the targeted instances
        --terminate                  OPTIONAL: This will terminate the specified instances. Must be combined with -s
        --rebuild                    OPTIONAL: This will terminate and relaunch the specified instances. Must be combined with -s
    -l, --list                       OPTIONAL: List out products and environments
    -d, --debug                      OPTIONAL: debug output
    -h, --help                       OPTIONAL: Display this screen
```


## Contributing

1. Fork it ( https://github.com/[my-github-username]/vominator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
