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

require 'docker'
include Docker


class HADockerConfig_Verify < HADockerConfig_Base

	# +l+::		listener
	# +s+::		server id(s)
	# +b+::		base url
	def initialize(l,s,b=nil)	
		super(l,s)
		@base_url = b || 'http://localhost:4243'
	end

	def parse
		@data = nil	# no input needed
	end

	def process
		# query a map of all running docker instances, together with their 
		# port forwardings
		config = { :base_url => @base_url }
		docker = API.new config
		
		begin
			current_docker_forwarding_state = get_docker_port_mapping_state(docker)
		rescue => e
			raise "Unable to get port mapping state from docker api, #{e.message}" 
		end

		# query servers in given listener
		haproxy_servers = Haproxy_Augeas.get_server_of_listener @listener

		# match those.
		res = {}
		haproxy_servers.each do |augeas_key, server_entry|
			server_id = (server_entry.split(" "))[0]
			res.store server_id, current_docker_forwarding_state[server_id]
		end
			
		return res
	end

	private
	# inspects all running container, looks up network settings and
	# returns a map from container id => NetworkSettings structure
	# +docker+:: 	Docker API object
	def get_docker_port_mapping_state(docker)
		res = {}
		cont = docker.containers
		cont.list.each do |c|

			e = cont.show(c["Id"]) || {}
			key = c["Id"][0..11]
			network_settings = e["NetworkSettings"] || {}
			res.store(key, network_settings)
		end
		res	
	end
end
