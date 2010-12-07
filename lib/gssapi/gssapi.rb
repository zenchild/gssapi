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
  extend FFI::Library
  ffi_lib 'gssapi_krb5'

  typedef :uint32, :OM_uint32

  class GssOID < FFI::Struct
    layout  :length   =>  :OM_uint32,
            :elements => :pointer # pointer of :void
  end

  class GssBufferDesc < FFI::Struct
    layout  :length => :size_t,
            :value  => :pointer # pointer of :void
  end

  class GssChannelBindingsStruct < FFI::Struct
    layout  :initiator_addrtype => :OM_uint32,
            :initiator_address  => GssBufferDesc,
            :acceptor_addrtype  => :OM_uint32,
            :acceptor_address   => GssBufferDesc,
            :application_data   => GssBufferDesc
  end


  # Function definitions
  # --------------------

  # OM_uint32 gss_import_name(OM_uint32 * minor_status, const gss_buffer_t input_name_buffer, const gss_OID input_name_type, gss_name_t * output_name);
  # @example:
  #   host_str = 'host@example.com'
  #   buff_str = GSSAPI::GssBufferDesc.new
  #   buff_str[:length] = host_str.length
  #   buff_str[:value] = FFI::MemoryPointer.from_string(host_str)
  #   name = FFI::MemoryPointer.new :pointer # gss_name_t
  #   min_stat = FFI::MemoryPointer.new :uint32
  #   maj_stat = GSSAPI.gss_import_name(min_stat, buff_str.pointer, GSSAPI.GSS_C_NT_HOSTBASED_SERVICE, name)
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
  #   oidstr = GSSAPI::GssBufferDesc.new
  #   maj_stat = GSSAPI.gss_oid_to_str(min_stat, GSSAPI.GSS_C_NT_HOSTBASED_SERVICE, oidstr.pointer)
  #   oidstr[:value].read_string
  attach_function :gss_oid_to_str, [:pointer, :pointer, :pointer], :OM_uint32

  # OM_uint32 gss_str_to_oid(OM_uint32 *minor_status, const gss_buffer_t oid_str, gss_OID *oid);
  # @example: Simulate GSS_C_NT_HOSTBASED_SERVICE
  #   min_stat = FFI::MemoryPointer.new :uint32
  #   str = "{ 1 2 840 113554 1 2 1 4 }"
  #   oidstr = GSSAPI::GssBufferDesc.new
  #   oidstr[:length] = str.length
  #   oidstr[:value] = FFI::MemoryPointer.from_string str
  #   oid = FFI::MemoryPointer.new :pointer
  #   min_stat = FFI::MemoryPointer.new :uint32
  #   maj_stat = GSSAPI.gss_str_to_oid(min_stat, oidstr.pointer, oid)
  #   oid = GSSAPI::GssOID.new(oid.get_pointer(0))
  attach_function :gss_str_to_oid, [:pointer, :pointer, :pointer], :OM_uint32


  # OM_uint32 gss_release_name(OM_uint32 * minor_status, gss_name_t * name);
  attach_function :gss_release_name, [:pointer, :pointer], :OM_uint32

  # OM_uint32  gss_init_sec_context(
  #   OM_uint32  *  minor_status,
  #   const gss_cred_id_t initiator_cred_handle,
  #   gss_ctx_id_t * context_handle,
  #   const gss_name_t target_name,
  #   const gss_OID mech_type,
  #   OM_uint32 req_flags,
  #   OM_uint32 time_req,
  #   const gss_channel_bindings_t input_chan_bindings,
  #   const gss_buffer_t input_token,
  #   gss_OID * actual_mech_type,
  #   gss_buffer_t output_token,
  #   OM_uint32 * ret_flags,
  #   OM_uint32 * time_rec);
  attach_function :gss_init_sec_context, [:pointer, :pointer, :pointer, :pointer, :pointer, :OM_uint32, :OM_uint32, :pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :OM_uint32


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
  

  # GSSAPI Status Codes
  GSS_S_COMPLETE = 0

  # GSSAPI Error contants
  #
  GSS_C_ROUTINE_ERROR_OFFSET = 16
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
    (18 << GSS_C_ROUTINE_ERROR_OFFSET) => "GSS_S_NAME_NOT_MN" }


end #end GSSAPI
