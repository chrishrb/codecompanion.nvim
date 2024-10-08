local config = require("codecompanion").config
local log = require("codecompanion.utils.log")

local _CONSTANTS = {
  PREFIX = "#",
}

---Check a message for a variable
---@param message string
---@param vars table
---@return string|nil
local function find(message, vars)
  for var, _ in pairs(vars) do
    if message:match("%f[%w" .. _CONSTANTS.PREFIX .. "]" .. _CONSTANTS.PREFIX .. var .. "%f[%W]") then
      return var
    end
  end
  return nil
end

---Check a message for any parameters that have been given to the variable
---@param message string
---@param var string
---@return string|nil
local function find_params(message, var)
  local pattern = _CONSTANTS.PREFIX .. var .. ":([^%s]+)"

  local params = message:match(pattern)
  if params then
    log:trace("Params found for variable: %s", params)
    return params
  end

  return nil
end

---@param chat CodeCompanion.Chat
---@param callback table
---@param params? string
---@return table|nil
local function resolve(chat, callback, params)
  local splits = vim.split(callback, ".", { plain = true })
  local path = table.concat(splits, ".", 1, #splits - 1)
  local func = splits[#splits]

  local ok, module = pcall(require, "codecompanion." .. path)

  -- User is using a custom callback
  if not ok then
    log:trace("Calling variable: %s", path .. "." .. func)
    return require(path)[func](chat, params)
  end

  log:trace("Calling variable: %s", path .. "." .. func)
  return module[func](chat, params)
end

---@class CodeCompanion.Variables
---@field vars table
local Variables = {}

---@param args? table
function Variables.new(args)
  local self = setmetatable({
    vars = config.strategies.chat.variables,
    args = args,
  }, { __index = Variables })

  return self
end

---Parse a message to detect if it references any variables
---@param chat CodeCompanion.Chat
---@param message string
---@return table|nil
function Variables:parse(chat, message)
  local var = find(message, self.vars)
  if not var then
    return
  end

  local found = self.vars[var]
  log:debug("Variable found: %s", var)

  local params = nil
  if found.opts and found.opts.has_params then
    params = find_params(message, var)
  end

  if (found.opts and found.opts.contains_code) and config.opts.send_code == false then
    log:debug("Sending of code disabled")
    return
  end

  return {
    var = var,
    type = found.type,
    content = resolve(chat, found.callback, params),
  }
end

---Replace a variable in a given message
---@param message string
---@param vars table
---@return string
function Variables:replace(message, vars)
  local var = _CONSTANTS.PREFIX .. vars.var
  return vim.trim(message:gsub(var, ""))
end

return Variables
