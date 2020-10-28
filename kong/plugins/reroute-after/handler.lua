local match = string.match
local http = require "resty.http"

local plugin = {
  PRIORITY = 715, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1",
}


local function iter(config_array)
  if type(config_array) ~= "table" then
    return noop
  end

  return function(config_array, i)
    i = i + 1

    local header_to_test = config_array[i]
    if header_to_test == nil then -- n + 1
      return nil
    end

    local header_to_test_name, header_to_test_value = match(header_to_test, "^([^,]+),*(.-)$")
    if header_to_test_value == "" then
      header_to_test_value = nil
    end

    return i, header_to_test_name, header_to_test_value
  end, config_array, 0
end

local function getCustomizationURL(plugin_conf, tenantName)

  kong.log.debug("buscando customização do tenant "..tenantName)

  for _, tenant, url in iter(plugin_conf.before) do
    -- kong.log.debug("iter tenant -> "..tenant)
    -- kong.log.debug("iter url -> "..url)
    if (tenant == tenantName) then
      return url
    end
  end

  return nil

end

local function make_request(plugin_conf, customizationUrl)
  local scheme, host, port, _ = unpack(http:parse_uri(customizationUrl))

  local client = http.new()
  client:set_timeout(plugin_conf.timeout)
  -- client:set_keepalive(10000)
  client:connect(host, port)
  if scheme == "https" then
      local ok, err = client:ssl_handshake()
      if not ok then
          kong.log.err(err)
          return kong.response.exit(500, { message = "An unexpected error occurred" })
      end
  end

  local res, err = client:request{
    path = customizationUrl,
    method = kong.request.get_method(),
    headers = kong.request.get_headers(),
    body = kong.request.get_raw_body(),
    keepalive_timeout = plugin_conf.timeout,
    ssl_verify = false
  }

  kong.log.debug("request feito")

  if not res then
    kong.log.err(err)
    return kong.response.exit(500, { message = "An unexpected error occurred" })
  end

  return res
end

-- runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)

  kong.log.debug("plugin:access -> request")
  kong.log.debug(kong.request)

  local tenantName = kong.request.get_header("X-Tenant")

  if tenantName ~= nil then
    kong.log.debug("que seja feita a customização")

    local customizationUrl = getCustomizationURL(plugin_conf, tenantName)

    if customizationUrl ~= nil then
      kong.log.debug("faz o before pra fora e pega a resposta e manda pro upstream service")

      local beforeRes = make_request(plugin_conf, customizationUrl)

      if not beforeRes or beforeRes.status >= 300 then
        return kong.response.exit(500, "fuuuuu")
      end

      kong.log.debug("resposta do before")
      kong.log.debug(beforeRes)

      kong.log.debug("reaponse has body: "..tostring(beforeRes.has_body))

      local body = beforeRes:read_body()
      kong.log.debug("response body")
      kong.log.debug(body)

    return kong.service.request.set_raw_body(body)
    end

  end

end

return plugin
