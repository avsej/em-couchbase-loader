# em-couchbase-loader

This script helps to measure performance of the [em-couchbase][1] gem.

## Setup

Clone repository:

    $ git clone git://github.com/avsej/em-couchbase-loader.git

Install dependencies, using bundler:

    $ cd em-couchbase-loader
    $ bundle install


## Usage

To show available options run script with `-?` argument:

    $ ./run.rb --help
    Usage: ./run.rb [options]
        -c, --concurrency NUM            Use NUM processes to run the test (default: 1)
        -n, --operations NUM             Number of operations (default: 100)
        -r, --ratio RATIO                The ratio if set/get operations (default: 0.5)
        -h, --hostname HOSTNAME          Hostname to connect to (default: nil)
        -b, --bucket NAME                Name of the bucket to connect to (default: "default")
        -u, --user USERNAME              Username to log with (default: none)
        -p, --passwd PASSWORD            Password to log with (default: none)
        -?, --help                       Show this message

## License

    Author:: Couchbase <info@couchbase.com>
    Copyright:: 2012 Couchbase, Inc.
    License:: Apache License, Version 2.0

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

[1]: https://github.com/avsej/couchbase-ruby-client
