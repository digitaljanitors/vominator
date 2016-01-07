# Vominator

**NOTE** This is still in development, and for now depends on VPCs and such being setup a certain way. More on that to come.

A CLI utility for managing AWS resources from yaml templates. This allow you to define resources within a dev VPC, and replicate that to a QA/Staging/Prod VPC without any additional work.


## Installation

1. `$ gem install vominator`
2. Create ~/.vominator.yaml
```
---
access_key_id: AWS_SECRET_KEY
secret_access_key: AWS_SECRET_ACCESS_KEY
configuration_path: Location to sample puke
key_pair_name: infrastructure@example.com
```
## Usage

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
