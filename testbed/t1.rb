#!/usr/bin/env ruby

require 'augeas'
require 'erb'
require 'ostruct'

module Haproxy_Docker

	AUG_HAPROXY = 	'/files/etc/haproxy/haproxy.cfg'
	HAPROXY_DOCKER_PREFIX	= 'dockerha-'

	def self.mkey(k)
		"#{AUG_HAPROXY}#{k}"
	end

	# returns all listeners as a map
	# key = listener name, value= list of augeas keys to subentries	
	def self.get_all_listeners
		res = {}
		aug = Augeas.open
		begin
			x = aug.match(mkey("/listen[*]/*")).each do |e|

				# grab name	
				key = e.split("/").last

				listen_section = aug.match("#{e}/*")
				res.store key, listen_section
			end
		ensure
			aug.close if aug
		end
		res
	end

	# like get_all_listeners but only returns listener names of
	# those prefixed by HAPROXY_DOCKER_PREFIX
	def self.get_my_managed_listeners
		res = {}
		aug = Augeas.open
		begin
			r = Regexp.new("#{HAPROXY_DOCKER_PREFIX}.*")
			x = aug.match(mkey("/listen[*]/*")).each do |e|

				# grab name	
				key = e.split("/").last
				next unless key.match r

				listen_section = aug.match("#{e}/*")
				res.store key, listen_section
			end
		ensure
			aug.close if aug
		end
		res
	end

	# given a real listener name, this methods returns a map containing
	# all server entries for this listener, keyed by the augeas key to the entry.
	def self.get_server_of_listener(listener_name)
		res = {}
		aug = Augeas.open
		begin
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					res.store server,aug.get(server)
				end
			end
		ensure
			aug.close if aug
		end
		res
	end

	# use an open struct to get a binding on a data structure for ERB rendering
	class RenderContext < OpenStruct
		def render(template)
			ERB.new(template).result(binding)
		end
	end

	# given an augeas key to a comment inside a listen section,
	# this renders an ERB output from the comment and the data map
	def self.evaluate_server_comment_entry(key_to_comment,data)
		res = nil
		aug = Augeas.open
		begin
			erb_text0 = aug.get(key_to_comment)
			# string prefix
			erb_text = erb_text0.split(" ")[1..-1].join(" ")
			r = RenderContext.new(data)
			res = r.render(erb_text)
		ensure
			aug.close if aug
		end
		res
	end

	# iterates the server entries of given listener and checks if
	# one matches server_id (may be a regex)
	def self.has_server_within_listener?(server_id,listener_name)
		aug = Augeas.open
		begin
			r = Regexp.new server_id
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					server_data = aug.get(server)
					return true if server_data.match r
				end
			end
		ensure
			aug.close if aug
		end
		return false
	end

	# iterates the server entries of given listener and checks if
	# one matches server_id (may be a regex). If so, it replaces
	# the entry by the one defined by gievn data structure (by
	# rendering the server comment)
	# If no entry matches, a new one is created.
	def self.ensure_server_within_listener(server_id,listener_name,server_data)
		aug = Augeas.open
		b_found = false
		begin
			r = Regexp.new server_id
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# pre-render the new data..
				key_to_command = "#{e}/#comment"
				new_server_entry = self.evaluate_server_comment_entry(key_to_command,server_data)

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					server_name = aug.get(server)
					if server_name.match r then
						b_found = true
puts "found, replacing"			
						# render new.
						aug.set server,new_server_entry
					end
				end
				if !b_found then
puts "adding new"
						new_key = "#{e}/server[last()+1]"
puts new_key
						aug.set! new_key,new_server_entry

				end
			end
  unless aug.save
    raise IOError, "Failed to save changes"
  end

		rescue => e
			STDERR.puts e
		ensure
			aug.close if aug
		end
	end
end


require 'pp'

#pp Haproxy_Docker::get_all_listeners
pp Haproxy_Docker::get_my_managed_listeners
#pp Haproxy_Docker::get_server_of_listener("appli5-backup")
#pp Haproxy_Docker::evaluate_server_comment_entry("/files/etc/haproxy/haproxy.cfg/listen[1]/dockerha-app1/#comment", { :id => "id1", :ip => "127.0.0.1", :port => "8080" })

#pp Haproxy_Docker::has_server_within_listener?("id4711", "dockerha-app1")
#pp Haproxy_Docker::has_server_within_listener?("id1", "dockerha-app1")

Haproxy_Docker::ensure_server_within_listener("id2","dockerha-app1", { :id => "id2", :ip => "127.0.0.1", :port => "8082" })
Haproxy_Docker::ensure_server_within_listener("id2","dockerha-app1", { :id => "id2", :ip => "127.0.0.1", :port => "8083" })
