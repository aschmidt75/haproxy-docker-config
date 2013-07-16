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

# Action Class for deleting server entries.
class HADockerConfig_Delete < HADockerConfig_Base

	# +l+::	listener
	# +s+::	server id(s)
	# +b+::	base url 
	def initialize(l,s,b = nil)	
		super(l,s)
		@base_url = b || 'http://localhost:4243'
	end

	# we expect @input_data to be ID[,ID,...], so split and parse it into @data
	def parse
		@data = @input_data.split(",")
	end

	# 
	def process
		raise "No server ids given" unless @data && @data.size > 0

		# just remove forwardings, we dont have to look up or sync anything here.
		Haproxy_Augeas::ensure_all_servers_absent_within_listener @data, @listener
	end

end
