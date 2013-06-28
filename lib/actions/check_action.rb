
class HADockerConfig_Check < HADockerConfig_Base

	def initialize(l,s)	
		super(l,s)
	end

	def parse
		# except a comma separated list of instance ids
		@data = @input_data.split(",")		if @input_data && @input_data.size > 0
	end

	def process
		if @data then
			# check if servers are defined, multiple server -
			return Haproxy_Augeas::has_servers_within_listener? @data, @listener
		else
			# just return all balancing members
			res = Haproxy_Augeas::get_server_of_listener @listener
			# map to align with same output format as above.
			return res.inject({}) { |res,(k,v)| res.store(v.to_s.split(" ")[0],true); res }
		end
	end
end
