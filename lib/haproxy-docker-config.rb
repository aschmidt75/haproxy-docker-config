#!/usr/bin/env ruby

$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'optparse'
require 'pp'

require 'haproxy-augeas'
require 'actions/action_base'
require 'actions/add_action'
require 'actions/check_action'

options = {}
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

	opts.on( '-a', '--add ID1[:PORT][,ID2[:PORT],...]', 'Add one or more container (identified by docker instance id) with optional public-facing port number') do |s|
		options[:add_string] = s
		options[:action_given] = true
	end

	opts.on( '-d', '--delete ID1[,ID2,...]', 'Delete one or more containers (identified by docker instance id) from balancing') do |s|
		options[:delete_string] = s
		options[:action_given] = true
	end

	opts.on( '-c', '--check ID1[,ID2,...]', 'Check if given containers (identified by docker instance id) are balanced by given listener') do |s|
		options[:check_string] = s
		options[:action_given] = true
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

if options[:add_string] then
	begin
		action = HADockerConfig_Add.new(
			options[:listener],
			options[:add_string]
		)	
		action.process

	rescue => e
		STDERR.puts("ERROR: Adding balancer entries. Not restarting. Please check haproxy.cfg")
		if options[:verbose] then
			STDERR.puts e
		end
	end
end
if options[:delete_string] then
	begin
		action = HADockerConfig_Delete.new(
			options[:listener],
			options[:delete_string]
		)	
		action.process

	rescue => e
		STDERR.puts("ERROR: Deleting balancer entries. Not restarting. Please check haproxy.cfg")
		if options[:verbose] then
			STDERR.puts e
		end
	end
end
if options[:check_string] then
	begin
		action = HADockerConfig_Check.new(
			options[:listener],
			options[:check_string]
		)	
		action.process

		# dump result

	rescue => e
		STDERR.puts("ERROR: Checking balancer entries.")
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


