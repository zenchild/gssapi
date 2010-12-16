require 'gssapi'
require 'base64'

host = 'example.org'
service  = 'host'

cli = GSSAPI::Simple.new(host, service)
tok = cli.init_context
stok = Base64.strict_encode64(tok)

# send tok
# get back continuation
stok = ""
tok = Base64.strict_decode64(stok)
cli.init_context(tok)

emsg = cli.wrap_message("This is a test message")
smsg = Base64.strict_encode64(emsg)

# send to remote
