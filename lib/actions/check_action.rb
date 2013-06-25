
class HADockerConfig_Check < HADockerConfig_Base

	def initialize(l,s)	
		super(l,s)
	end

	def parse
		@data = @input_data.split(",")
	end

	def process
		# check if servers are defined, multiple server -
		pp Haproxy_Augeas::has_servers_within_listener? @data, @listener

	end
end
