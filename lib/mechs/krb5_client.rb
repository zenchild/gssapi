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
  module Mech
    class Krb5Client

      # param [String] fqdn the fully qualified host name of the remote server
      def initialize(fqdn)
        @host_name = fqdn
        @int_name = nil

        import_name
        init_sec_context
      end



      def import_name
        buff_str = LibGSSAPI::GssBufferDesc.new
        host_str = "host@#{@host_name}"
        buff_str.value = host_str
        name = FFI::MemoryPointer.new :pointer # gss_name_t
        min_stat = FFI::MemoryPointer.new :uint32

        maj_stat = LibGSSAPI.gss_import_name(min_stat, buff_str.pointer, LibGSSAPI.GSS_C_NT_HOSTBASED_SERVICE, name)
        @int_name = name.get_pointer(0)
        LibGSSAPI::GssNameT.new(@int_name)
        #LibGSSAPI::GSS_C_ROUTINE_ERRORS[maj_stat]
      end

      def init_sec_context
        min_stat = FFI::MemoryPointer.new :uint32
        no_cred = FFI::MemoryPointer.new :pointer  # GSS_C_NO_CREDENTIAL
        no_cred.write_int 0
        ctx  = FFI::MemoryPointer.new :pointer  # GSS_C_NO_CONTEXT
        ctx.write_int 0
        no_chn_bind = FFI::MemoryPointer.new :pointer  #
        no_chn_bind.write_int 0

        input_token = LibGSSAPI::GssBufferDesc.new
        input_token.value = nil
        output_token = LibGSSAPI::GssBufferDesc.new
        output_token.value = nil

        mech = LibGSSAPI.gss_mech_krb5
        maj_stat = LibGSSAPI.gss_init_sec_context(min_stat,
                                               nil,
                                               ctx,
                                               @int_name,
                                               mech,
                                               (LibGSSAPI::GSS_C_MUTUAL_FLAG | LibGSSAPI::GSS_C_SEQUENCE_FLAG),
                                               0,
                                               nil,
                                               input_token.pointer,
                                               nil,
                                               output_token.pointer,
                                               nil,
                                               nil)

        if(maj_stat == 0 || maj_stat == 1)
          #LibGSSAPI::GssBufferT.new(output_token.pointer)
          @context = ctx.get_pointer(0)
        else
          puts LibGSSAPI::GSS_C_ROUTINE_ERRORS[maj_stat]
        end

        puts maj_stat
      end

    end
  end
end
