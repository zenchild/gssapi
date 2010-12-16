require 'gssapi'
require 'base64'

host = 'example.org'
service  = 'host'
keytab = 'path/to/keytab' # this is optional, but probably required if not running as root

srv = GSSAPI::Simple.new(host, service, keytab)
srv.acquire_credentials

# receive token
stok = ""
tok = Base64.strict_decode64(stok)
otok = srv.accept_context(tok)
stok = Base64.strict_encode64(otok)

# receive Wrapped msg
emsg = ""
msg = Base64.strict_decode64(emsg)
srv.unwrap_message(msg)
