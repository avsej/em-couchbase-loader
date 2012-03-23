#!/usr/bin/env ruby
# Author:: Couchbase <info@couchbase.com>
# Copyright:: 2012 Couchbase, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rubygems'
begin
  require 'bundler/setup'
rescue LoadError
  # don't worry if bundler isn't available
  # the script could be installed somewhere in PATH
end
require 'em-couchbase'
require 'optparse'
require 'logger'

options = {
  :hostname => "127.0.0.1",
  :port => 8091,
  :bucket => "default",
  :concurrency => 1,
  :ratio => 0.5,
  :operations => 10_000,
  :prefix => 'em-couchbase:',
  :size => 256,
  :slice => 1_000,
  :tick => 1,
  :use_fork => true,
  :mechanism => :select
}

LOGGER = Logger.new(STDOUT)

trap("INT") do
  LOGGER.info("Caught SIGINT. Terminating...")
  exit
end

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"
  opts.on("-f", "--[no-]use-fork", "Use fork, if it is available (default: #{options[:use_fork].inspect})") do |v|
    options[:use_fork] = v
  end
  opts.on("-m", "--mechanism MECH", "The mechanism for multiplexing I/O. EventMachine supports (:select, :epoll, :kqueue) (default: #{options[:mechanism].inspect})") do |v|
    options[:mechanism] = v.to_sym
  end
  opts.on("-t", "--tick SECONDS", "The interval for timer (default: #{options[:tick].inspect})") do |v|
    options[:tick] = v.to_i
  end
  opts.on("-S", "--slice NUM", "The number of operation scheduled each timer occurence (default: #{options[:slice].inspect})") do |v|
    options[:slice] = v.to_i
  end
  opts.on("-P", "--prefix PREFIX", "The prefix used for keys (default: #{options[:prefix].inspect})") do |v|
    options[:prefix] = v.to_i
  end
  opts.on("-c", "--concurrency NUM", "Use NUM processes to run the test (default: #{options[:concurrency].inspect})") do |v|
    options[:concurrency] = v.to_i
  end
  opts.on("-n", "--operations NUM", "Number of operations (default: #{options[:operations].inspect})") do |v|
    options[:operations] = v.to_i
  end
  opts.on("-r", "--ratio RATIO", "The percent of GETs from 1 (default: #{options[:ratio].inspect})") do |v|
    options[:ratio] = v.to_f
  end
  opts.on("-s", "--size SIZE", "Number of bytes for values (default: #{options[:size].inspect})") do |v|
    options[:size] = v.to_i
  end
  opts.on("-h", "--hostname HOSTNAME", "Hostname to connect to (default: #{options[:hostname].inspect})") do |v|
    host, port = v.split(':')
    options[:hostname] = host.empty? ? '127.0.0.1' : host
    options[:port] = port.to_i > 0 ? port.to_i : 8091
  end
  opts.on("-b", "--bucket NAME", "Name of the bucket to connect to (default: #{options[:bucket].inspect})") do |v|
    options[:bucket] = v.empty? ? "default" : v
  end
  opts.on("-u", "--user USERNAME", "Username to log with (default: none)") do |v|
    options[:user] = v
  end
  opts.on("-p", "--passwd PASSWORD", "Password to log with (default: none)") do |v|
    options[:passwd] = v
  end
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on_tail("-?", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

case options[:mechanism]
when :epoll
  EM.epoll = true
when :kqueue
  EM.kqueue = true
else
  # select
end

IGNORED_ERRORS = [
  EM::Protocols::Couchbase::Error::NotFound
]

HAVE_FORK = begin
              Process.fork { exit }
              true
            rescue NotImplementedError
              false
            end

USE_FORK = options[:use_fork]

def spawn_worker(&block)
  if HAVE_FORK && USE_FORK
    Process.fork(&block)
  else
    Thread.new(&block)
  end
end

def wait_for(workers)
  if HAVE_FORK && USE_FORK
    workers.each do |pid|
      Process.wait(pid)
    end
  else
    workers.each do |tid|
      tid.join
    end
  end
end

ops_per_fork = (options[:operations] / options[:concurrency].to_f).ceil
workers = []

options[:concurrency].times do |n|
  workers << spawn_worker do
    $0 = "#{__FILE__}: fork ##{n}"
    value = $0.dup
    value << ('.' * (options[:size] - value.size))

    EM.run do
      cc = EM::Protocols::Couchbase.connect(:hostname => options[:hostname],
                                            :port => options[:port],
                                            :bucket => options[:bucket])
      cc.on_error do |_, error|
        warn "Failed to connect to #{options[:hostname]}:#{options[:port]}: #{error}"
        EM.stop
      end
      on_complete = lambda do |ret|
        ops_per_fork -= 1
        if options[:verbose]
          if ret.success? || IGNORED_ERRORS.include?(ret.error.class)
            case ret.operation
            when :set
              STDERR.print("s")
            when :get
              STDERR.print("g")
            end
          else
            STDERR.print("E")
          end
        end
        EM.stop if ops_per_fork < 0
      end
      EM.add_periodic_timer(options[:tick]) do
        if options[:verbose]
          STDERR.print(".")
        end
        options[:slice].times do |t|
          if rand > options[:ratio]
            cc.set("#{options[:prefix]}fork-#{n}:#{t}", value, &on_complete)
          else
            cc.get("#{options[:prefix]}fork-#{n}:#{t}", &on_complete)
          end
        end
      end
    end
  end
end

wait_for(workers)
