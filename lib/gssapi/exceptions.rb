#############################################################################
# Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>
#
#
# This file is part of the Ruby GSSAPI library.
# 
# GSSAPI is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# GSSAPI is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with GSSAPI.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
module GSSAPI
  class GssApiError < StandardError

    include LibGSSAPI

    def message; to_s + ": " + @s; end

    def initialize(*args)
      if args.length != 2
        @s = '(no error info)'
	return
      end
      maj_stat, min_stat = *args
      min = FFI::MemoryPointer.new :OM_uint32
      message_context = FFI::MemoryPointer.new :OM_uint32
      @s = ''
      oid = GssOID.gss_c_no_oid
      min_stat = min_stat.read_uint32
      [[maj_stat, GSS_C_GSS_CODE],
       [min_stat, GSS_C_MECH_CODE]].each do |m, t|
        message_context.write_int 0
        begin
          out_buff = ManagedGssBufferDesc.new
          maj = gss_display_status(min, m, t, oid,
                                             message_context, out_buff.pointer)
          if (maj != 0)
            @s += "failed to retrieve GSSAPI display for status #{m}"
            @s += " of major status #{maj_stat}, minor_status #{min_stat}\n"
            @s += "(with major status #{maj}, minor status #{min.read_uint32}\n"
	    break
          end
          @s += out_buff.value.to_s + "\n"
        end while message_context.read_int != 0
      end
    end
  end
end
