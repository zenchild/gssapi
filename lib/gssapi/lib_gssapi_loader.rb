=begin
Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>

Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php
=end
module GSSAPI
  module LibGSSAPI

    # Heimdal supported the *_iov functions befor MIT did so in some OS distributions if
    # you need IOV support and MIT does not provide it try the Heimdal libs and then
    # before doing a "require 'gssapi'" do a "require 'gssapi/heimdal'" and that will attempt
    # to load the Heimdal libs
    case RUBY_PLATFORM
    when /linux/
      case GSSAPI_LIB_TYPE
      when :mit
        GSSAPI_LIB = 'libgssapi_krb5.so.2'
      when :heimdal
        GSSAPI_LIB = 'libgssapi.so.2'
      end
      ffi_lib GSSAPI_LIB, FFI::Library::LIBC
    when /darwin/
      case GSSAPI_LIB_TYPE
      when :mit
        GSSAPI_LIB = '/usr/lib/libgssapi_krb5.dylib'
      when :heimdal
        # use Heimdal Kerberos since Mac MIT Kerberos is OLD. Do a "require 'gssapi/heimdal'" first
        GSSAPI_LIB = '/usr/heimdal/lib/libgssapi.dylib'
      end
      ffi_lib GSSAPI_LIB, FFI::Library::LIBC
    when /mswin|mingw32|windows/
      # Pull the gssapi32 path from the environment if it exist, otherwise use the default in Program Files
      gssapi32_path = ENV['gssapi32'] ? ENV['gssapi32'] : 'C:\Program Files (x86)\MIT\Kerberos\bin\gssapi32.dll'
      ffi_lib gssapi32_path, FFI::Library::LIBC  # Required the MIT Kerberos libraries to be installed
      ffi_convention :stdcall
    else
      raise LoadError, "This platform (#{RUBY_PLATFORM}) is not supported by ruby gssapi."
    end

  end
end
