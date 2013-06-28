#!/usr/bin/env ruby

$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'optparse'
require 'pp'

require 'haproxy-augeas'
require 'actions/action_base'
require 'actions/add_action'
require 'actions/check_action'

require 'json/pure'
require 'yaml'

options = {
	:output_style => :plain
	}
optparse = OptionParser.new do |opts|
	opts.on( '-h', '--help', 'Show help details') do	
		puts opts
		exit
	end

	opts.on( '-l', '--listen LISTENER', 'Perform actions on LISTENER listen service. Mandatory') do |s|
		options[:listener] = s
	end

	opts.on( '-r', '--restart', 'Hot-restart haproxy after modifying config') do 
		options[:restart] = true
	end

	opts.on( '-v', '--verbose', 'Be verbose about what i do.') do 
		options[:verbose] = true
	end

	opts.on( '--yaml', 'Output as yaml.') do 
		options[:output_style] = :yaml
	end

	opts.on( '--json', 'Output as json.') do 
		options[:output_style] = :json
	end

	opts.on( '-a', '--add ID1[:PORT][,ID2[:PORT],...]', 'Add one or more container (identified by docker instance id) with optional private port number. Public-facing port will be looked up.') do |s|
		options[:add_string] = s
		options[:action_given] = :add
	end

	opts.on( '-d', '--delete ID1[,ID2,...]', 'Delete one or more containers (identified by docker instance id) from balancing') do |s|
		options[:delete_string] = s
		options[:action_given] = :delete
	end

	opts.on( '-c', '--check [ID1,ID2,...]', 'Check if given containers (identified by docker instance id) are balanced by given listener. Return list of all balanced containers if no id give') do |s|
		options[:check_string] = s
		options[:action_given] = :check
	end
end

optparse.parse!

# check args
unless (options[:listener] && options[:listener].size > 0) then
	STDERR.puts("ERROR: Must supply a listener name (-l, --listen), see --help")
	exit 1
end

unless options[:action_given] then
	STDERR.puts("ERROR: Must choose one of -a, -d, -c as actions. See --help")
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
				puts format("%-20s\tbalanced\t%s:%s",instance_id,m[:ip],m[:port])
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
		end
	end
end
if options[:action_given] == :delete then
	begin
		action = HADockerConfig_Delete.new(
			options[:listener],
			options[:delete_string]
		)	
		action.process

	rescue => e
		STDERR.puts("ERROR: Deleting balancer entries. Not restarting. Please check haproxy.cfg. #{e.message}")
		if options[:verbose] then
			STDERR.puts e
		end
	end
end
if options[:action_given] == :check then
	begin
		action = HADockerConfig_Check.new(
			options[:listener],
			options[:check_string]
		)	
		res = action.process

		# dump result
		if options[:output_style] == :plain then
			res.each do |instance_id, status|
				puts format("%-20s\t%s",instance_id,((status==true) ? "balanced" : "not_balanced"))
			end
		end
		if options[:output_style] == :yaml then
			puts res.to_yaml
		end
		if options[:output_style] == :json then
			puts res.to_json
		end

	rescue => e
		STDERR.puts("ERROR: Checking balancer entries.  #{e.message}" )
		if options[:verbose] then
			STDERR.puts e
		end
	end
end

if options[:restart] then
	begin
		system('echo 123')
	rescue => e
		STDERR.puts("ERROR: Restarting haproxy. Please check service.")
		if options[:verbose] then
			STDERR.puts e
		end
	end
end


