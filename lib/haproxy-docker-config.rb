#!/usr/bin/env ruby

# The MIT License (MIT)
# 
# Copyright (c) 2013 Andreas Schmidt 
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'optparse'
require 'pp'

require 'haproxy-augeas'
require 'actions/action_base'
require 'actions/add_action'
require 'actions/delete_action'
require 'actions/check_action'
require 'actions/verify_action'

require 'json/pure'
require 'yaml'

# option defaults
options = {
    :output_style => :plain
}
multiple_options_error = false

# parse 
optparse = OptionParser.new do |opts|
  opts.on('-h', '--help', 'Show help details') do
    puts opts
    exit
  end

  opts.on('-l', '--listen LISTENER', 'Perform actions on LISTENER listen service. Mandatory') do |s|
    options[:listener] = s
  end

  opts.on('--docker-url IPADDRESS[:PORT]', 'URL (and optional port) for the Docker host where docker -d is running. Default http://localhost:4243') do |uri|
    options[:base_url] = uri
  end

  opts.on('-a', '--add ID1[:PORT][,ID2[:PORT],...]', 'Add one or more containers (identified by docker container id) with optional private port number. Public-facing port will be looked up.') do |s|
    multiple_options_error = true if options[:action_given]
    options[:add_string] = s
    options[:action_given] = :add
  end

  opts.on('-d', '--delete ID1[,ID2,...]', 'Delete one or more containers (identified by docker container id) from balancing') do |s|
    multiple_options_error = true if options[:action_given]

    options[:delete_string] = s
    options[:action_given] = :delete
  end

  opts.on('-c', '--check [ID1,ID2,...]', 'Check if given containers (identified by docker container id) are balanced by given listener. Return list of all balanced containers if no id give') do |s|
    multiple_options_error = true if options[:action_given]
    options[:check_string] = s
    options[:action_given] = :check
  end

  opts.on('--verify', 'Check if all server entries in given listener are backed by a running container.') do
    multiple_options_error = true if options[:action_given]
    options[:action_given] = :verify
  end
  opts.on('-r', '--restart', 'Restart haproxy after modifying config. (must have rights to, assumes service haproxy configured)') do
    options[:restart] = true
  end

  opts.on('-h', '--hot-restart [pidfile]', 'Hot Restart haproxy after modifying config. Default pidfile=/var/run/haproxy.pid') do |f|
    options[:hotrestart] = true
    options[:hotrestart_pidfile] = f
  end

  opts.on('-v', '--verbose', 'Be verbose about what i do.') do
    options[:verbose] = true
  end

  opts.on('-s', '--show', 'show target servers of given listener.') do
    options[:show] = true
  end

  opts.on('--yaml', 'Output as yaml.') do
    options[:output_style] = :yaml
  end

  opts.on('--json', 'Output as json.') do
    options[:output_style] = :json
  end
end

optparse.parse!

if multiple_options_error
  STDERR.puts 'ERROR: May only choose one of -a, -d, -c, -v. Please see --help'
  exit 3
end
# check args
unless options[:listener] && options[:listener].size > 0
  STDERR.puts('ERROR: Must supply a listener name (-l, --listen), see --help')
  exit 1
end

unless options[:action_given]
  STDERR.puts('ERROR: Must choose one of -a, -d, -c as actions. See --help')
  exit 2
end

# TODO: quick check whether listener name is valid

if options[:action_given] == :add then
  begin
    action = HADockerConfig_Add.new(
        options[:listener],
        options[:add_string],
        options[:base_url]
    )
    res = action.process
    # dump result
    if options[:output_style] == :plain then
      res.each do |instance_id, m|
        puts format("%-20s\tbalanced\t%s:%s", instance_id, m[:ip], m[:port])
      end
    end
    if options[:output_style] == :yaml then
      puts res.to_yaml
    end
    if options[:output_style] == :json then
      puts res.to_json
    end


  rescue => e
    STDERR.puts("ERROR: Adding balancer entries. Not restarting. Please check haproxy.cfg. #{e.message}")
    if options[:verbose] then
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
    end
  end
end
if options[:action_given] == :delete then
  begin
    action = HADockerConfig_Delete.new(
        options[:listener],
        options[:delete_string],
        options[:base_url]
    )
    action.process

  rescue => e
    STDERR.puts("ERROR: Deleting balancer entries. Not restarting. Please check haproxy.cfg. #{e.message}")
    if options[:verbose] then
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
    end
  end
end
if options[:action_given] == :check
  begin
    action = HADockerConfig_Check.new(
        options[:listener],
        options[:check_string],
        options[:base_url]
    )
    res = action.process

    # dump result
    if options[:output_style] == :plain
      res.each do |instance_id, status|
        puts format("%-20s\t%s", instance_id, (status ? 'balanced' : 'not_balanced'))
      end
    end
    if options[:output_style] == :yaml then
      puts res.to_yaml
    end
    if options[:output_style] == :json then
      puts res.to_json
    end

  rescue => e
    STDERR.puts("ERROR: Checking balancer entries.  #{e.message}")
    if options[:verbose] then
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
    end
  end
end
if options[:action_given] == :verify then
  begin
    action = HADockerConfig_Verify.new(
        options[:listener],
        "*",
        options[:base_url]
    )
    res = action.process

    # dump result
    if options[:output_style] == :plain then
      res.each do |instance_id, details|
        puts format('%-20s\t%s', instance_id, ((details != nil) ? 'found' : 'not_found'))
      end
    end
    if options[:output_style] == :yaml then
      puts res.to_yaml
    end
    if options[:output_style] == :json then
      puts res.to_json
    end

  rescue => e
    STDERR.puts("ERROR: Verifying balancer entries.  #{e.message}")
    if options[:verbose] then
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
    end
  end
end

# process any restart options afterwards
if options[:restart] then
  begin
    system('service haproxy restart')
  rescue => e
    STDERR.puts('ERROR: Restarting haproxy. Please check service.')
    if options[:verbose] then
      STDERR.puts e
    end
  end
end
if options[:hotrestart] then
  # see /usr/share/doc/haproxy/haproxy-en.txt.gz, 2.4.1) Hot reconfiguration
  begin
    p = options[:hotrestart_pidfile] || "/var/run/haproxy.pid"
    cmd = "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -p #{p} -sf $(cat #{p})"
    if options[:verbose] then
      puts "Executing #{cmd}"
    end
    system cmd
  rescue => e
    STDERR.puts('ERROR: Hot-Restarting haproxy. Please check service.')
    if options[:verbose] then
      STDERR.puts e
    end
  end
end


if options[:show] then

  begin
    res0 = Haproxy_Augeas.get_server_of_listener(options[:listener])
    res = res0.inject([]) do |result, (k, v)|
      result << v; result
    end

    # dump result
    if options[:output_style] == :plain then
      puts res.join("\n")
    end
    if options[:output_style] == :yaml then
      puts res.to_yaml
    end
    if options[:output_style] == :json then
      puts res.to_json
    end

  rescue => e
    STDERR.puts("ERROR: Checking balancer entries.  #{e.message}")
    if options[:verbose]
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
    end
  end
end
