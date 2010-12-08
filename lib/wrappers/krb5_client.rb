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
  module Wrapper
    class Krb5Client

      # param [String] fqdn the fully qualified host name of the remote server
      def initialize(fqdn)
        @host_name = fqdn
        @int_name = nil

        import_name
      end

      private

      def import_name
        buff_str = GSSAPI::GssBufferDesc.new
        host_str = "host@#{@host_name}"
        buff_str[:length] = host_str.length
        buff_str[:value] = FFI::MemoryPointer.from_string(host_str)
        name = FFI::MemoryPointer.new :pointer # gss_name_t
        min_stat = FFI::MemoryPointer.new :uint32

        maj_stat = GSSAPI.gss_import_name(min_stat, buff_str.pointer, GSSAPI.GSS_C_NT_HOSTBASED_SERVICE, name)
        @int_name = name.get_pointer(0)
        #GSSAPI::GSS_C_ROUTINE_ERRORS[maj_stat]
        ObjectSpace.define_finalizer(self, finalize_name_t(@int_name.address))
      end


      # ==== Finalizers ====

      # @param [FixNum] p_address the value of the Pointer address
      def finalize_name_t(p_address)
        proc {
          puts "Finalizing name_ptr for address #{p_address}"
          min_stat = FFI::MemoryPointer.new :uint32
          name_ptr = FFI::MemoryPointer.new :pointer
          name_ptr.write_pointer p_address
          maj_stat = GSSAPI.gss_release_name(min_stat, name_ptr)
          puts "Finalize status: #{maj_stat}"
        }
      end

    end
  end
end
