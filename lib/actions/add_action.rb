require 'docker'
include Docker

class HADockerConfig_Add < HADockerConfig_Base

	# listener
	# server id(s)
	# base url
	def initialize(l,s,b)	
		super(l,s)
		@base_url = b || 'http://localhost:4243'
	end

	def parse
		@data = []
		@input_data.split(",").each do |id_port_pair|
			a = id_port_pair.split(":")
			# no port? add -1 to indicate that we should find out ourselves
			a << "-1" if a.size < 2
			@data << [ a[0],a[1].to_i ] 
		end
	end

	def process
		# query a map of all running docker instances, together with their 
		# port forwardings
		config = { :base_url => @base_url }
		docker = API.new config
		
		current_docker_forwarding_state = {}
		cont = docker.containers
		cont.list.each do |c|

			e = cont.show(c["Id"]) || {}
			key = e["Config"]["Hostname"] || c["Id"]
			network_settings = e["NetworkSettings"] || {}
			current_docker_forwarding_state.store(key, network_settings)
		end
		
		res = {}
		# for each instance to be balanced,
		@data.each do |instance_id, source_port|
			# check that this is running ..
			state = current_docker_forwarding_state[instance_id]
			raise "No running container found for id=#{instance_id}"  unless state

			port_mappings = state["PortMapping"] || {}
			ip_address = state["IpAddress"]

			# get the public facing port
			if source_port > 0
				# source port is given
				public_port = port_mappings[source_port.to_s]
			else
				# source port is not given, grab the first one (if there is one)
				public_port = port_mappings.first[0] if port_mappings.size > 0
			end
			raise "Did not find port forwarding for id=#{instance_id}, port=#{source_port}" unless public_port
		
			res.store instance_id, { :port => public_port, :ip => ip_address }
		end		

		# initiate forwardings..
		Haproxy_Augeas::ensure_all_servers_within_listener res, @listener
	
		return res
	end
end
