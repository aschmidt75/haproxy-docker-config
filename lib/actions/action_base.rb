
class HADockerConfig_Base
	attr_reader	:listener, :input_data, :data

	def initialize(listener,input_data)
		@listener = listener
		@input_data = input_data
		parse
	end
	
	# take input from cmd line, parse appropriately, put into data
	def parse
	end

	def process
	end

	def to_s
		"#{self.class.to_s}:[listener=#{@listener}, data=#{data.to_s}, input=#{input_data}]"
	end
end
