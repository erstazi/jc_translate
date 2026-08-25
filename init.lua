local modname = core.get_current_modname()
local S = core.get_translator(core.get_current_modname())
local modpath = core.get_modpath(core.get_current_modname())
local http = core.request_http_api and core.request_http_api()
local mod_version = modname .. "/1.0.1"

if not http then
  core.log("error", "[" .. modname .. "] HTTP API is not available.")
  core.log("error", "[" .. modname .. "] Add " .. modname .. " to secure.http_mods in you minetest.conf.")
  return
end

local API_URL = core.settings:get("jc_translate.api_url")
if not API_URL or API_URL == "" then
  core.log("error", "[" .. modname .. "] jc_translate.api_url is not configured.")
end

local API_KEY = core.settings:get("jc_translate.api_key")
if not API_KEY or API_KEY == "" then
  core.log("error", "[" .. modname .. "] jc_translate.api_key is not configured.")
end

local HTTP_TIMEOUT = tonumber(core.settings:get("jc_translate.timeout")) or 10

local LANGUAGES = {
  en = "English",
  es = "Spanish",
  fr = "French",
  de = "German",
  pl = "Polish",
  tr = "Turkish",
  zh = "Chinese",
  vi = "Vietnamese",
  ru = "Russian",
  uk = "Ukrainian",
  nl = "Dutch",
  ko = "Korean",
  ar = "Arabic",
  hu = "Hungarian",
}

local LANGUAGE_ORDER = {
  "en",
  "es",
  "fr",
  "de",
  "pl",
  "tr",
  "zh",
  "vi",
  "ru",
  "uk",
  "nl",
  "ko",
  "ar",
  "hu",
}

local function normalize_language(lang)
  if not lang or lang == "" then
    return "en"
  end

  lang = lang:gsub("_", "-")
  lang = lang:lower()
  if lang == "zh"
    or lang == "zh-cn"
    or lang == "zh-hans"
    or lang == "zh-hans-cn" then
    return "zh"
  end

  local base = lang:match("^([a-z][a-z])")
  if base and LANGUAGES[base] then
    return base
  end

  return "en"
end

local function get_detected_language(name)
  local info = core.get_player_information(name)
  if not info then
    return "en"
  end

  return normalize_language(info.lang_code)
end

local function get_player_language(player)
  local meta = player:get_meta()
  local selected = meta:get_string("jc_translate:language")
  if selected ~= "" and LANGUAGES[selected] then
    return selected
  end

  return get_detected_language(player:get_player_name())
end

local function save_player_language(player, language)
  local meta = player:get_meta()
  meta:set_string("jc_translate:language", language)
end

local function get_api_language(language)
  if language == "zh" then
    return "zh-Hans"
  end

  return language
end

local function escape_formspec(text)
  return core.formspec_escape(text)
end

local function show_language_formspec(name)
  local player = core.get_player_by_name(name)
  if not player then
    return
  end

  local current = get_player_language(player)

  local language_list = {}
  local current_index = 1

  for index, code in ipairs(LANGUAGE_ORDER) do
    table.insert(language_list, S(LANGUAGES[code]))

    if code == current then
      current_index = index
    end
  end

  local current_language = S(LANGUAGES[current] or current)

  local formspec = table.concat({
    "formspec_version[6]",
    "size[9.5,8]",
    "label[0.5,0.4;" .. S("Your Current Language: @1.", core.colorize("#FFFF00", escape_formspec(current_language) ) ) .. "]",
    "label[0.5,1.1;" .. escape_formspec( S("Choose Your Language:") ) .. "]",
    "dropdown[0.5,1.4;7,0.8;language;",
    table.concat(language_list, ","),
    ";" .. current_index .. ";false]",
    "button_exit[0.5,6.8;4,1;cancel;" .. escape_formspec( S("Cancel") ) .. "]",
    "button_exit[4.8,6.8;4,1;save;" .. escape_formspec( S("Save Language") ) .. "]",
  })

  core.show_formspec(name, "jc_translate:language", formspec )
end

core.register_chatcommand("lang", {
  params = "",
  description = S("Choose Your Language"),
  func = function(name, param)
    show_language_formspec(name)
    return true
  end,
})


core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "jc_translate:language" then
    return
  end

  if fields.cancel then
    return
  end

  if not fields.save then
    return
  end

  local selected_name = fields.language

  if not selected_name or selected_name == "" then
    core.chat_send_player(player:get_player_name(), S("Invalid language selection.") )
    return
  end

  local selected_code

  for _, code in ipairs(LANGUAGE_ORDER) do
    if S(LANGUAGES[code]) == selected_name then
      selected_code = code
      break
    end
  end

  if not selected_code then
    core.chat_send_player(player:get_player_name(), S("Invalid language selection.") )
    return
  end

  save_player_language(player, selected_code)

  core.chat_send_player(player:get_player_name(), S("Translation language set to @1.", S(LANGUAGES[selected_code]) ) )
end)


core.register_on_joinplayer(function(player)
  local name = player:get_player_name()
  local meta = player:get_meta()
  local stored = meta:get_string("jc_translate:language")

  if stored == "" then
    local detected = get_detected_language(name)
    save_player_language(player, detected)

    core.log("action", "[" .. modname .. "] " .. name .. " detected language: " .. detected )
  else
    stored = normalize_language(stored)
    save_player_language(player, stored)

    core.log("action", "[" .. modname .. "] " .. name .. " stored language: " .. stored )
  end
end)

local function get_chat_prefix_text(name)
  if core.get_modpath("ranks") and type(ranks) == "table" and ranks.get_rank and ranks.get_def then
    local rank = ranks.get_rank(name)
    if rank then
      local def = ranks.get_def(rank)
      if def and def.prefix_text then
        return def.prefix_text .. " "
      end
    end
  end
  return ""
end

local function get_chat_prefix(name)
  if core.get_modpath("ranks") and type(ranks) == "table" and ranks.get_rank and ranks.get_def then
    local rank = ranks.get_rank(name)
    if rank then
      local def = ranks.get_def(rank)
      if def and def.prefix and def.colour then
        local colour
        if type(def.colour) == "table" and core.rgba then
          colour = core.rgba(
            def.colour.r,
            def.colour.g,
            def.colour.b,
            def.colour.a
          )
        elseif type(def.colour) == "string" then
          colour = def.colour
        else
          colour = "#ffffff"
        end
        return core.colorize(colour, def.prefix) .. " "
      end
    end
  end

  return ""
end

local function protect_urls(text)
  local urls = {}
  local index = 0

  text = text:gsub("https?://%S+", function(url)
    index = index + 1

    local placeholder = "ZXQU" .. tostring(index) .. "ZXQ"
    urls[placeholder] = url

    return placeholder
  end)

  return text, urls
end

local function restore_urls(text, urls)
  for placeholder, url in pairs(urls) do
    text = text:gsub(placeholder, function()
      return url
    end)
  end

  return text
end

local function protect_usernames(text)
  local names = {}
  local protected = text

  for _, player in ipairs(core.get_connected_players()) do
    local name = player:get_player_name()

    if name ~= "" then
      table.insert(names, name)
    end
  end

  -- Longest names first so overlapping names are handled correctly.
  table.sort(names, function(a, b)
    return #a > #b
  end)

  local placeholders = {}

  for index, name in ipairs(names) do
    local placeholder = "ZXQP" .. tostring(index) .. "ZXQ"

    -- Escape Lua pattern characters in the username.
    local escaped_name = name:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")

    protected = protected:gsub(escaped_name, placeholder)

    placeholders[placeholder] = name
  end

  return protected, placeholders
end


local function restore_usernames(text, placeholders)
  for placeholder, name in pairs(placeholders) do
    text = text:gsub(placeholder, name)
  end

  return text
end

local function translate_text(text, source_language, target_language, callback)
  if source_language == target_language then
    callback(text)
    return
  end

  local protected_text, url_placeholders = protect_urls(text)
  local username_placeholders

  protected_text, username_placeholders = protect_usernames(protected_text)

  if not API_KEY or API_KEY == "" then
    callback(nil, "API key is not configured")
    return
  end

  local source = get_api_language(source_language)
  local target = get_api_language(target_language)

  local request_data = core.write_json({
    q = protected_text,
    source = source,
    target = target,
    format = "text",
    api_key = API_KEY,
  })

  http.fetch({
    url = API_URL,
    method = "POST",
    data = request_data,
    timeout = HTTP_TIMEOUT,
    extra_headers = {
      "Content-Type: application/json",
      "Accept: application/json",
    },
    user_agent = mod_version,
  }, function(result)

    if not result.succeeded then
      callback(nil, "HTTP request failed")
      return
    end

    if result.code ~= 200 then
      callback(nil, "HTTP " .. tostring(result.code))
      return
    end

    local data = core.parse_json(result.data)

    if not data or not data.translatedText then
      callback(nil, "Invalid LibreTranslate response")
      return
    end

    local restored = restore_usernames(
      data.translatedText,
      username_placeholders
    )

    restored = restore_urls(
      restored,
      url_placeholders
    )

    callback(restored)
  end)
end

core.register_on_chat_message(function(name, message)
  local sender = core.get_player_by_name(name)

  if not sender then
    return true
  end

  local source_language = get_player_language(sender)

  local players = core.get_connected_players()

  local recipients = {}

  local languages_needed = {}

  for _, player in ipairs(players) do

    local recipient_name = player:get_player_name()

    local target_language = get_player_language(player)

    recipients[recipient_name] = target_language

    languages_needed[target_language] = true
  end

  local translated = {}

  local pending = 0

  local prefix = get_chat_prefix(name)
  local prefix_text = get_chat_prefix_text(name)

  core.log("action", "CHAT: " .. prefix_text .. "<" .. name .. "> " .. message)

  for target_language in pairs(languages_needed) do
    if target_language == source_language then
      translated[target_language] = message
    else
      pending = pending + 1

      translate_text(
        message,
        source_language,
        target_language,
        function(result)

          if result then
            translated[target_language] = result
          else
            translated[target_language] = message
            core.log( "warning", "[" .. modname .. "] Translation failed: " .. source_language .. " -> " .. target_language )
          end

          pending = pending - 1

          if pending == 0 then
            for recipient_name, language in pairs(recipients) do
              local output = translated[language]
              if output then
                core.chat_send_player(recipient_name, prefix .. "<" .. name .. "> " .. output )
              end
            end
          end
        end
      )
    end
  end

  if pending == 0 then
    for recipient_name, language in pairs(recipients) do
      local output = translated[language]
      if output then
        core.chat_send_player(recipient_name, prefix .. "<" .. name .. "> " .. output )
      end
    end
  end

  return true
end)