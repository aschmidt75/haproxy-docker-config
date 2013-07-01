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

# Action class for check action
class HADockerConfig_Check < HADockerConfig_Base

	# +l+::		listener name
	# +s+::		container id spec as cs-list
	def initialize(l,s,b=nil)	
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
