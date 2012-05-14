page = require("webpage").create()
url = phantom.args[0]
path = phantom.args[1]

page.viewportSize =
  width:  1024
  height: 768

page.clipRect =
  top:    0
  left:   0
  width:  1024
  height: 768

page.open url, (status) ->
  if status == "success"
    page.render path
    phantom.exit()
  else
    throw new Error("failed to load " + url)