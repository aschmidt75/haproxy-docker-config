
class HADockerConfig_Add < HADockerConfig_Base

	def initialize(l,s)	
		super(l,s)
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
		pp @data
	end
end
