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
require 'ffi'

module GSSAPI
  module LibGSSAPI
    extend FFI::Library
    
    ffi_lib File.basename Dir.glob("/usr/lib/libgssapi*").first

    typedef :uint32, :OM_uint32

    class GssOID < FFI::Struct
      layout  :length   =>  :OM_uint32,
              :elements => :pointer # pointer of :void
    end

    # @example
    #   buff = GssBufferDesc.new
    #   str = FFI::MemoryPointer.from_string("This is the string")
    #   buff[:length] = str.size
    #   buff[:value] = str
    class GssBufferDesc < FFI::Struct
      layout  :length => :size_t,
              :value  => :pointer # pointer of :void
    end

    class MGssBufferDesc < FFI::ManagedStruct
      layout  :length => :size_t,
              :value  => :pointer # pointer of :void

      def self.release(ptr)
        puts "Releasing MGssBufferDesc at #{ptr.address}"
        min_stat = FFI::MemoryPointer.new :uint32
        maj_stat = LibGSSAPI.gss_release_buffer(min_stat, ptr)
      end
    end

    # @example
    #   iov_buff = GssIOVBufferDesc.new
    #   str = FFI::MemoryPointer.from_string("This is the string")
    #   iov_buff[:type] = 1
    #   iov_buff[:buffer][:length] = str.size
    #   iov_buff[:buffer][:value] = str
    class GssIOVBufferDesc < FFI::Struct
      layout  :type   => :OM_uint32,
              :buffer => GssBufferDesc
    end
    
    class GssChannelBindingsStruct < FFI::Struct
      layout  :initiator_addrtype => :OM_uint32,
              :initiator_address  => GssBufferDesc,
              :acceptor_addrtype  => :OM_uint32,
              :acceptor_address   => GssBufferDesc,
              :application_data   => GssBufferDesc
    end

    class GssPointer < FFI::AutoPointer
      def address_of
        ptr_p = FFI::MemoryPointer.new :pointer
        ptr_p.write_pointer(self)
      end

      def self.release(ptr)
        if( ptr.address == 0 )
          puts "NULL POINTER: Not freeing"
          return
        else
          puts "Releasing #{self.name}"
          self.release_ptr(ptr)
        end
      end
    end

    # A wrapper around gss_name_t so that it garbage collects
    class GssNameT < GssPointer
      def self.release_ptr(name_ptr)
        puts "Releasing gss_name_t at #{name_ptr.address}" if $DEBUG
        min_stat = FFI::MemoryPointer.new :uint32
        maj_stat = LibGSSAPI.gss_release_name(min_stat, name_ptr)
      end
    end

    # A wrapper around gss_buffer_t so that it garbage collects
    class GssBufferT < GssPointer
      def self.release_ptr(buffer_ptr)
        puts "Releasing gss_buffer_t at #{buffer_ptr.address}" if $DEBUG
        min_stat = FFI::MemoryPointer.new :uint32
        maj_stat = LibGSSAPI.gss_release_buffer(min_stat, buffer_ptr)
      end
    end

    class GssCtxIdT < GssPointer
      def self.release_ptr(context_ptr)
        min_stat = FFI::MemoryPointer.new :uint32
        empty_buff = LibGSSAPI::GssBufferDesc.new
        empty_buff[:length] = 0
        empty_buff[:value] = nil
        maj_stat = LibGSSAPI.gss_delete_sec_context(min_stat, context_ptr, empty_buff.pointer)
      end

      def self.gss_c_no_context
        no_ctx  = GSSAPI::LibGSSAPI::GSS_C_NO_CREDENTIAL # GSS_C_NO_CONTEXT
        self.new(GSSAPI::LibGSSAPI::GSS_C_NO_CREDENTIAL)
      end
    end


    # OM_uint32 gss_release_buffer(OM_uint32 * minor_status, gss_buffer_t buffer);

    # Function definitions
    # --------------------

    # OM_uint32 gss_import_name(OM_uint32 * minor_status, const gss_buffer_t input_name_buffer, const gss_OID input_name_type, gss_name_t * output_name);
    # @example:
    #   host_str = 'host@example.com'
    #   buff_str = GSSAPI::LibGSSAPI::GssBufferDesc.new
    #   buff_str[:length] = host_str.length
    #   buff_str[:value] = FFI::MemoryPointer.from_string(host_str)
    #   name = FFI::MemoryPointer.new :pointer # gss_name_t
    #   min_stat = FFI::MemoryPointer.new :uint32
    #   maj_stat = GSSAPI::LibGSSAPI.gss_import_name(min_stat, buff_str.pointer, GSSAPI::LibGSSAPI.GSS_C_NT_HOSTBASED_SERVICE, name)
    #   name = name.get_pointer(0)
    # Remember to free the allocated name (gss_name_t) space with gss_release_name
    attach_function :gss_import_name, [:pointer, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_export_name(OM_uint32 * minor_status, const gss_name_t input_name, gss_buffer_t exported_name);
    attach_function :gss_export_name, [:pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_canonicalize_name(OM_uint32 * minor_status, const gss_name_t input_name, const gss_OID mech_type, gss_name_t * output_name)
    attach_function :gss_canonicalize_name, [:pointer, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_oid_to_str(OM_uint32 *minor_status, const gss_OID oid, gss_buffer_t oid_str);
    # @example:
    #   min_stat = FFI::MemoryPointer.new :uint32
    #   oidstr = GSSAPI::LibGSSAPI::GssBufferDesc.new
    #   maj_stat = GSSAPI::LibGSSAPI.gss_oid_to_str(min_stat, GSSAPI::LibGSSAPI.GSS_C_NT_HOSTBASED_SERVICE, oidstr.pointer)
    #   oidstr[:value].read_string
    attach_function :gss_oid_to_str, [:pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_str_to_oid(OM_uint32 *minor_status, const gss_buffer_t oid_str, gss_OID *oid);
    # @example: Simulate GSS_C_NT_HOSTBASED_SERVICE
    #   min_stat = FFI::MemoryPointer.new :uint32
    #   str = "{ 1 2 840 113554 1 2 1 4 }"
    #   oidstr = GSSAPI::LibGSSAPI::GssBufferDesc.new
    #   oidstr[:length] = str.length
    #   oidstr[:value] = FFI::MemoryPointer.from_string str
    #   oid = FFI::MemoryPointer.new :pointer
    #   min_stat = FFI::MemoryPointer.new :uint32
    #   maj_stat = GSSAPI::LibGSSAPI.gss_str_to_oid(min_stat, oidstr.pointer, oid)
    #   oid = GSSAPI::LibGSSAPI::GssOID.new(oid.get_pointer(0))
    attach_function :gss_str_to_oid, [:pointer, :pointer, :pointer], :OM_uint32


    # OM_uint32  gss_init_sec_context(OM_uint32  *  minor_status, const gss_cred_id_t initiator_cred_handle,
    #   gss_ctx_id_t * context_handle, const gss_name_t target_name, const gss_OID mech_type, OM_uint32 req_flags,
    #   OM_uint32 time_req, const gss_channel_bindings_t input_chan_bindings, const gss_buffer_t input_token,
    #   gss_OID * actual_mech_type, gss_buffer_t output_token, OM_uint32 * ret_flags, OM_uint32 * time_rec);
    attach_function :gss_init_sec_context, [:pointer, :pointer, :pointer, :pointer, :pointer, :OM_uint32, :OM_uint32, :pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32  gss_wrap(OM_uint32  *  minor_status, const gss_ctx_id_t context_handle, int conf_req_flag,
    #   gss_qop_t qop_req, const gss_buffer_t input_message_buffer, int * conf_state, gss_buffer_t output_message_buffer);
    # @example:
    #   min_stat = FFI::MemoryPointer.new :uint32
    # Remember to free the allocated output_message_buffer with gss_release_buffer
    attach_function :gss_wrap, [:pointer, :pointer, :int, :OM_uint32, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 GSSAPI_LIB_FUNCTION gss_wrap_iov(	OM_uint32 * minor_status, gss_ctx_id_t 	context_handle,
    #   int conf_req_flag, gss_qop_t 	qop_req, int * 	conf_state, gss_iov_buffer_desc * 	iov, int 	iov_count );
    attach_function :gss_wrap_iov, [:pointer, :pointer, :int, :OM_uint32, :pointer, :pointer, :int], :OM_uint32

    # OM_uint32 gss_wrap_aead(OM_uint32 * minor_status, gss_ctx_id_t context_handle, int conf_req_flag, gss_qop_t qop_req, gss_buffer_t input_assoc_buffer,
    #  gss_buffer_t input_payload_buffer, int * conf_state, gss_buffer_t output_message_buffer);
    attach_function :gss_wrap_aead, [:pointer, :pointer, :int, :OM_uint32, :pointer, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32  gss_unwrap(OM_uint32  *  minor_status, const gss_ctx_id_t context_handle,
    #   const gss_buffer_t input_message_buffer, gss_buffer_t output_message_buffer, int * conf_state, gss_qop_t * qop_state);
    # @example:
    #   min_stat = FFI::MemoryPointer.new :uint32
    # Remember to free the allocated output_message_buffer with gss_release_buffer
    attach_function :gss_unwrap, [:pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_delete_sec_context(OM_uint32 * minor_status, gss_ctx_id_t * context_handle, gss_buffer_t output_token);
    attach_function :gss_delete_sec_context, [:pointer, :pointer, :pointer], :OM_uint32

    # OM_uint32 gss_release_name(OM_uint32 * minor_status, gss_name_t * name);
    attach_function :gss_release_name, [:pointer, :pointer], :OM_uint32

    # OM_uint32 gss_release_buffer(OM_uint32 * minor_status, gss_buffer_t buffer);
    attach_function :gss_release_buffer, [:pointer, :pointer], :OM_uint32

    # Variable definitions
    # --------------------

    attach_variable :GSS_C_NT_HOSTBASED_SERVICE, :pointer # type gss_OID
    attach_variable :GSS_C_NT_EXPORT_NAME, :pointer # type gss_OID
    attach_variable :gss_mech_krb5, :pointer # type gss_OID
    attach_variable :gss_mech_set_krb5, :pointer # type gss_OID_set
    attach_variable :gss_nt_krb5_name, :pointer # type gss_OID
    attach_variable :gss_nt_krb5_principal, :pointer # type gss_OID
    attach_variable :gss_nt_krb5_principal, :pointer # type gss_OID_set





    # Flag bits for context-level services.
    GSS_C_DELEG_FLAG        = 1
    GSS_C_MUTUAL_FLAG       = 2
    GSS_C_REPLAY_FLAG       = 4
    GSS_C_SEQUENCE_FLAG     = 8
    GSS_C_CONF_FLAG         = 16
    GSS_C_INTEG_FLAG        = 32
    GSS_C_ANON_FLAG         = 64
    GSS_C_PROT_READY_FLAG   = 128
    GSS_C_TRANS_FLAG        = 256
    GSS_C_DELEG_POLICY_FLAG = 32768


    # Message Offsets
    GSS_C_CALLING_ERROR_OFFSET = 24
    GSS_C_ROUTINE_ERROR_OFFSET = 16
    GSS_C_SUPPLEMENTARY_OFFSET = 0
    # GSS_C_CALLING_ERROR_MASK ((OM_uint32) 0377ul)
    # GSS_C_ROUTINE_ERROR_MASK ((OM_uint32) 0377ul)
    # GSS_C_SUPPLEMENTARY_MASK ((OM_uint32) 0177777ul)


    # QOP (Quality of Protection)
    GSS_C_QOP_DEFAULT       = 0


    # GSSAPI Status Codes
    GSS_S_COMPLETE = 0

    GSS_C_SUPPLEMENTARY_CODES = {
			(1 << (GSS_C_SUPPLEMENTARY_OFFSET + 0)) => "GSS_S_CONTINUE_NEEDED",
			(1 << (GSS_C_SUPPLEMENTARY_OFFSET + 1)) => "GSS_S_DUPLICATE_TOKEN",
			(1 << (GSS_C_SUPPLEMENTARY_OFFSET + 2)) => "GSS_S_OLD_TOKEN",
			(1 << (GSS_C_SUPPLEMENTARY_OFFSET + 3)) => "GSS_S_UNSEQ_TOKEN",
			(1 << (GSS_C_SUPPLEMENTARY_OFFSET + 4)) => "GSS_S_GAP_TOKEN"
    }


    # GSSAPI Error contants
    #
    # Routine Errors
    GSS_C_ROUTINE_ERRORS = {
      (1 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_MECH",
      (2 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_NAME",
      (3 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_NAMETYPE",
      (4 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_BINDINGS",
      (5 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_STATUS",
      (6 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_SIG",
      (7 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_NO_CRED",
      (8 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_NO_CONTEXT",
      (9 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_DEFECTIVE_TOKEN",
      (10 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_DEFECTIVE_CREDENTIAL",
      (11 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_CREDENTIALS_EXPIRED",
      (12 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_CONTEXT_EXPIRED",
      (13 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_FAILURE",
      (14 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_BAD_QOP",
      (15 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_UNAUTHORIZED",
      (16 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_UNAVAILABLE",
      (17 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_DUPLICATE_ELEMENT",
      (18 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_NAME_NOT_MN"
    }

    # IOV Buffer Types (gssapi_ext.h)
    GSS_IOV_BUFFER_TYPE_EMPTY       = 0
    GSS_IOV_BUFFER_TYPE_DATA        = 1	 # Packet data
    GSS_IOV_BUFFER_TYPE_HEADER      = 2  # Mechanism header
    GSS_IOV_BUFFER_TYPE_MECH_PARAMS = 3	 # Mechanism specific parameters
    GSS_IOV_BUFFER_TYPE_TRAILER     = 7	 # Mechanism trailer
    GSS_IOV_BUFFER_TYPE_PADDING     = 9  # Padding
    GSS_IOV_BUFFER_TYPE_STREAM      = 10 # Complete wrap token
    GSS_IOV_BUFFER_TYPE_SIGN_ONLY   = 11 # Sign only packet data
    # Flags
    GSS_IOV_BUFFER_FLAG_MASK        = 0xFFFF0000
    GSS_IOV_BUFFER_FLAG_ALLOCATE    = 0x00010000 # indicates GSS should allocate
    GSS_IOV_BUFFER_FLAG_ALLOCATED   = 0x00020000 # indicates caller should free



    # Various Null values. (gssapi.h)
		GSS_C_NO_NAME           = FFI::Pointer.new(:pointer, 0) # ((gss_name_t) 0)
		GSS_C_NO_BUFFER         = FFI::Pointer.new(:pointer, 0) # ((gss_buffer_t) 0)
		GSS_C_NO_OID            = FFI::Pointer.new(:pointer, 0) # ((gss_OID) 0)
		GSS_C_NO_OID_SET        = FFI::Pointer.new(:pointer, 0) # ((gss_OID_set) 0)
		GSS_C_NO_CONTEXT        = FFI::Pointer.new(:pointer, 0) # ((gss_ctx_id_t) 0)
		GSS_C_NO_CREDENTIAL     = FFI::Pointer.new(:pointer, 0) # ((gss_cred_id_t) 0)
		GSS_C_NO_CHANNEL_BINDINGS = FFI::Pointer.new(:pointer, 0) # ((gss_channel_bindings_t) 0)
		def self.GSS_C_EMPTY_BUFFER
      buff = GssBufferDesc.new
      buff[:length] = 0
		  buff[:value]  = nil
      buff
    end


  end #end LibGSSAPI
end #end GSSAPI
