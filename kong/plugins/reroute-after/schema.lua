local typedefs = require "kong.db.schema.typedefs"
local pl_template = require "pl.template"
local tx = require "pl.tablex"
local validate_header_name = require("kong.tools.utils").validate_header_name

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local function validate_customization(pair)
  local name, value = pair:match("^([^,]+),*(.-)$")
  if name == nil then
    return nil, string.format("'%s' tenant is incorrect", tostring(name))
  end

  if value == nil then
    return nil, string.format("'%s' custom URL is incorrect", tostring(value))
  end
  return true
end

local reroute_record = {
  type = "record",
  fields = {
    {
      header = {
        type = "string"
      }
    },{
      tenant = {
        type = "string"
      }
    },{
      endpoint = {
        type = "string"
      }
    }
  }
}

local reroute_array = {
  type = "array",
  default = {},
  elements = reroute_record
}

local reroute_array_record = {
  type = "record",
  default = {},
  fields = { 
    reroutes = reroute_array
  }
}

local reroute_value_array = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^,]+,.*$", custom_validator = validate_customization },
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

          -- { after = reroute_array },
          { after = reroute_record },
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

          -- -- a standard defined field (typedef), with some customizations
          -- { request_header = typedefs.header_name {
          --     required = true,
          --     default = "Hello-World" } },
          -- { response_header = typedefs.header_name {
          --     required = true,
          --     default = "Bye-World" } },
          -- { ttl = { -- self defined field
          --     type = "integer",
          --     default = 600,
          --     required = true,
          --     gt = 0, }}, -- adding a constraint for the value
        },
        entity_checks = {
          -- add some validation rules across fields
          -- the following is silly because it is always true, since they are both required
          -- { at_least_one_of = { "request_header", "response_header" }, },
          -- We specify that both header-names cannot be the same
          -- { distinct = { "request_header", "response_header"} },
        },
      },
    },
  },
}

return schema
