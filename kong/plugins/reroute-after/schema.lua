local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local reroute_record = {
  type = "record",
  fields = {
    {
      header_name = {
        type = "string",
        required = true
      }
    },{
      header_value = {
        type = "string",
        required = true
      }
    },{
      url = {
        type = "string",
        required = true
      }
    }
  }
}

local reroute_array = {
  type = "array",
  default = {},
  elements = reroute_record
}

local schema = {
  name = plugin_name,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {

          { after = reroute_array },
          { timeout = {
              type = "integer",
              default = 10000,
              required = true
            }
          },
          {
            run_on_preflight = {
              type = "boolean",
              default = false,
              required = false
            }
          }

        },
        entity_checks = {

        },
      },
    },
  },
}

return schema
