#!/usr/bin/env ruby


require 'augeas'
require 'erb'
require 'ostruct'

module Haproxy_Augeas

	# Augeas resource to manage
	AUG_HAPROXY = 			'/files/etc/haproxy/haproxy.cfg'

	# naming convention: prefix out own listen entries with this string
	HAPROXY_DOCKER_PREFIX	= 	'dockerha-'

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
	def self.evaluate_server_comment_entry(aug,key_to_comment,data)
		res = nil

		erb_text0 = aug.get(key_to_comment)
		# string prefix
		erb_text = erb_text0.split(" ")[1..-1].join(" ")
		r = RenderContext.new(data)
		res = r.render(erb_text).strip

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

	# checks if servers are defined in given listener. Takes an array
	# of server_ids, returns a map of server_id => found boolean
	def self.has_servers_within_listener?(server_ids,listener_name)
		res = server_ids.inject({}) { |res,e| res[e] = false; res }
		aug = Augeas.open
		begin
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					server_data = aug.get(server)
					server_ids.each do |server_id|
						if server_data =~ /#{server_id}/ then
							res.store server_id, true
						end
					end
				end
			end
		ensure
			aug.close if aug
		end
		res
	end

	# iterates the server entries of given listener and checks if
	# one matches server_id (may be a regex). If so, it replaces
	# the entry by the one defined by given data structure (by
	# rendering the server comment)
	# If no entry matches, a new one is created by rendering the comment.
	# In result, the server entry will be define in the given listener.
	def self.ensure_server_within_listener(server_id,listener_name,server_data)
		aug = Augeas.open
		b_found = false
		begin
			server_data[:id] = server_id
			r = Regexp.new server_id
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# pre-render the new data..
				key_to_command = "#{e}/#comment"
				new_server_entry = self.evaluate_server_comment_entry(aug,key_to_command,server_data)

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					server_name = aug.get(server)
					if server_name.match r then
						b_found = true

						# rewrite existing entry (maybe port has changed)
						aug.set server,new_server_entry
					end
				end
				if !b_found then
						# add a new entry
						new_key = "#{e}/server[last()+1]"
						aug.set! new_key,new_server_entry

				end
			end
			# save changes
			unless aug.save
				raise IOError, "Failed to save changes"
			end

		ensure
			aug.close if aug
		end
	end
	
	# removes a server from a listener
	def self.ensure_server_absent_within_listener(server_id,listener_name)
		aug = Augeas.open
		begin
			r = Regexp.new server_id
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				aug.match("#{e}/server").each do |server|
					server_name = aug.get(server)
					if server_name.match r then
						aug.rm server
						break			# break out since we manipulated the tree..
					end
				end
			end
			# save changes
			unless aug.save
				raise IOError, "Failed to save changes"
			end

		ensure
			aug.close if aug
		end
	end

	# same as ensure_server_within_listener, but on a map server_id => server_data
	# for all entries in the map.
	# It will replace existing entries and add missing ones. It does not remove
	# existing entries.
	def self.ensure_all_servers_within_listener(server_map,listener_name)
		aug = Augeas.open
		b_missing = server_map.clone
		begin
			x = aug.match(mkey("/listen[*]/*")).each do |e|
				key = e.split("/").last
				next if key != listener_name

				# grab out the server lines
				aug.match("#{e}/server").each do |server|
					server_name = aug.get(server)
					
					# iterate the server_map, find all matching keys
					server_map.each do |server_id, server_data|
						server_data[:id] = server_id
						if server_name =~ /#{server_id}/ then
							# render the new data..
							key_to_command = "#{e}/#comment"
							new_server_entry = self.evaluate_server_comment_entry(aug,key_to_command,server_data)

							# rewrite existing entry (maybe port has changed)
							aug.set server,new_server_entry
							
							# remove from missing map, because we processed this one.
							b_missing.delete server_id
						end
					end	
				end
                                # b_missing contains all entries that have not been replaced. Add them here.
                                to_be_added = []
                                b_missing.each do |server_id, server_data|
                                        # render the new data..
                                        key_to_command = "#{e}/#comment"
                                        new_server_entry = self.evaluate_server_comment_entry(aug,key_to_command,server_data)
                                        to_be_added << new_server_entry
                                end

                                # add a new entry
                                new_key = "#{e}/server[last()+1]"
                                aug.set! new_key, to_be_added
			end

			# save changes
			unless aug.save
				raise IOError, "Failed to save changes"
			end

		ensure
			aug.close if aug
		end
	end
end





