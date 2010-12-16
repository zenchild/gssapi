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
  class Simple

    # Initialize a new GSSAPI::Simple object
    # @param [String] host_name the fully qualified host name
    # @param [String] service_name the service name. This can either be in the form svc@example.org 
    #   or just svc.  If there is no '@example.org' part the host_name will be appended. If no
    #   service_name is given at all the default service of 'host' will be used.
    def initialize(host_name, service_name=nil, keytab=nil)
      @host = host_name
      @service = service_name.nil? ? "host@#{@host}" : (service_name.include?('@') ? service_name : "#{service_name}@#{@host}")
      @int_svc_name = import_name(@service)
      @context = nil # the security context
      @scred = nil # the service credentials.  really only used for the server-side via acquire_credentials
      set_keytab(keytab) unless keytab.nil?
    end


    # Convert a String to a GSSAPI usable buffer (gss_buffer_desc)
    # @param [String] str the string to convert
    def import_name(str)
      buff_str = LibGSSAPI::GssBufferDesc.new
      buff_str.value = str
      name = FFI::MemoryPointer.new :pointer # gss_name_t
      min_stat = FFI::MemoryPointer.new :uint32

      maj_stat = LibGSSAPI.gss_import_name(min_stat, buff_str.pointer, LibGSSAPI.GSS_C_NT_HOSTBASED_SERVICE, name)
      raise GssApiError, "gss_import_name did not return GSS_S_COMPLETE.  Error code: maj: #{maj_stat}, min: #{min_stat.read_int}" if maj_stat != 0

      LibGSSAPI::GssNameT.new(name.get_pointer(0))
    end

    # Initialize the GSS security context (client initiator).  If there was a previous call that issued a
    #   continue you can pass the continuation token in via the token param.
    # @param [String] in_token an input token sent from the remote service in a continuation.
    # @return [String, true] if a continuation flag is set it will return the output token that is needed to send
    #   to the remote host.  Otherwise it returns true and the GSS security context has been established.
    def init_context(in_token = nil)
      min_stat = FFI::MemoryPointer.new :uint32
      ctx = (@context.nil? ? LibGSSAPI::GssCtxIdT.gss_c_no_context.address_of : @context.address_of)
      mech = LibGSSAPI::GssOID.gss_c_no_oid
      input_token = LibGSSAPI::GssBufferDesc.new
      input_token.value = in_token
      output_token = LibGSSAPI::GssBufferDesc.new
      output_token.value = nil


      maj_stat = LibGSSAPI.gss_init_sec_context(min_stat,
                                                nil,
                                                ctx,
                                                @int_svc_name,
                                                mech,
                                                (LibGSSAPI::GSS_C_MUTUAL_FLAG | LibGSSAPI::GSS_C_SEQUENCE_FLAG),
                                                0,
                                                nil,
                                                input_token.pointer,
                                                nil,
                                                output_token.pointer,
                                                nil,
                                                nil)

      raise GssApiError, "gss_init_sec_context did not return GSS_S_COMPLETE.  Error code: maj: #{maj_stat}, min: #{min_stat.read_int}" if maj_stat > 1
      
      @context = LibGSSAPI::GssCtxIdT.new(ctx.get_pointer(0))
      maj_stat == 1 ? output_token.value : true
    end


    # Accept a security context that was initiated by a remote peer.
    # @param [String] in_token The token sent by the remote client to initiate the context
    # @return [String, true] If this is part of a continuation it will return a token to be passed back to the remote
    #   otherwise it will simply return true.
    def accept_context(in_token)
      raise GssApiError, "No credentials yet acquired. Call #{self.class.name}#acquire_credentials first" if @scred.nil?

      min_stat = FFI::MemoryPointer.new :uint32
      ctx = (@context.nil? ? LibGSSAPI::GssCtxIdT.gss_c_no_context.address_of : @context.address_of)
      no_chn_bind = LibGSSAPI::GSS_C_NO_CHANNEL_BINDINGS
      client = FFI::MemoryPointer.new :pointer  # Will hold the initiating client name after the call
      mech = FFI::MemoryPointer.new :pointer  # Will hold the mech being used after the call
      in_tok = GSSAPI::LibGSSAPI::GssBufferDesc.new
      in_tok.value = in_token
      out_tok = GSSAPI::LibGSSAPI::GssBufferDesc.new
      maj_stat = LibGSSAPI.gss_accept_sec_context(min_stat,
                                                  ctx,
                                                  @scred,
                                                  in_tok.pointer,
                                                  no_chn_bind,
                                                  client,
                                                  mech,
                                                  out_tok.pointer,
                                                  nil, nil, nil)

      raise GssApiError, "gss_accept_sec_context did not return GSS_S_COMPLETE.  Error code: maj: #{maj_stat}, min: #{min_stat.read_int}" if maj_stat > 1

      out_tok.value
    end


    # Acquire security credentials. This does not log you in. It grabs the credentials from a cred cache or keytab.
    # @param [Hash] opts options to pass to the gss_acquire_cred function.
    # @option opts [String] :usage The credential usage type ('accept', 'initiate', 'both').  It defaults to 'accept' since
    #   this method is most usually called on the server only.
    # @return [true] It will return true if everything succeeds and the @scred variable will be set for future methods. If
    #   an error ocurrs an exception will be raised.
    def acquire_credentials(opts = {:usage => 'accept'})
      min_stat = FFI::MemoryPointer.new :uint32
      scred = FFI::MemoryPointer.new :pointer

      case opts[:usage]
      when 'accept'
        usage = LibGSSAPI::GSS_C_ACCEPT
      when 'initiate'
        usage = LibGSSAPI::GSS_C_INITIATE
      when 'both'
        usage = LibGSSAPI::GSS_C_BOTH
      else
        raise GssApiError, "Bad option passed to #{self.class.name}#acquire_credentials"
      end

      maj_stat = LibGSSAPI.gss_acquire_cred(min_stat, @int_svc_name, 0, LibGSSAPI::GSS_C_NO_OID_SET, usage, scred, nil, nil)
      raise GssApiError, "gss_acquire_cred did not return GSS_S_COMPLETE.  Error code: maj: #{maj_stat}, min: #{min_stat.read_int}" if maj_stat != 0

      @scred = LibGSSAPI::GssCredIdT.new(scred.get_pointer(0))
      true
    end

    # Add a path to a custom keytab file
    # @param [String] keytab the path to the keytab
    def set_keytab(keytab)
      maj_stat = LibGSSAPI.krb5_gss_register_acceptor_identity(keytab)
      raise GssApiError, "krb5_gss_register_acceptor_identity did not return GSS_S_COMPLETE.  Error code: maj: #{maj_stat}, min: #{min_stat.read_int}" if maj_stat != 0
      true
    end

  end # Simple
end # GSSAPI
