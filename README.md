# Vominator

**NOTE** This is still in development, and for now depends on VPCs and such being setup a certain way. This gem is also not yet published, so if you want to play with it you will need to clone this repo and build/install it.

A CLI utility for managing AWS resources from yaml templates. This allow you to define resources within a dev VPC, and replicate that to a QA/Staging/Prod VPC without any additional work.

This CLI utility expects that your VPCs are setup in a specific way. The creation of this will be bundled in, however for now you can use this Init script which should be able to create things in the required structure.

https://gist.github.com/chkelly/95c3314aa1331a7ac438

This CLI utility will require you to define resources via YAML files. This should be kept in a repo of yours. You can see https://github.com/digitaljanitors/sample-puke for a reference.




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
