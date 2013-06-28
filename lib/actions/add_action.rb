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

	# we expect @input_data to be ID:[PORT][,ID:[:PORT]], so split and parse it into @data
	def parse
		@data = []
		@input_data.split(",").each do |id_port_pair|
			a = id_port_pair.split(":")
			# no port? add 0 to indicate that we should find out ourselves
			a << "0" if a.size < 2
			@data << [ a[0],a[1].to_i ] 
		end
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

		res = {}
		# for each instance to be balanced,
		@data.each do |instance_id, source_port|
			# check that this is running by looking it up in our map
			state = current_docker_forwarding_state[instance_id]
			raise "No running container found for id=#{instance_id}"  unless state

			# grab out mappings and local ip address
			port_mappings = state["PortMapping"] || {}
			ip_address = state["IpAddress"]

			raise "Unable to look up port mapping for id=#{instance_id}" unless port_mappings && ip_address

			# get the public facing port according to source_port
			if source_port > 0
				# source port is given, so look up the public facing port
				public_port = port_mappings[source_port.to_s]
			else
				# source port is not given, grab the first one (if there is one)
				public_port = port_mappings.first[1] if port_mappings.size > 0
			end
			# no port? -> get out.
			raise "Did not find port forwarding for id=#{instance_id}, port=#{source_port}" unless public_port
		
			# 
			res.store instance_id, { :port => public_port, :ip => ip_address }
		end		

		# initiate forwardings..
		# res has the structure of what ensure_ expects:
		# #id => { :port => #port, :ip => #localip }
		Haproxy_Augeas::ensure_all_servers_within_listener res, @listener
	
		return res
	end

	private
	# inspects all running container, looks up network settings and
	# returns a map from container id => NetworkSettings structure
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
