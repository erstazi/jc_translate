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

local function get_translations_enabled(player)
  local meta = player:get_meta()
  local value = meta:get_string("jc_translate:enabled")

  -- Default is enabled.
  if value == "" then
    meta:set_string("jc_translate:enabled", "yes")
    return true
  end

  -- Migrate old values.
  if value == "true" then
    meta:set_string("jc_translate:enabled", "yes")
    return true
  elseif value == "false" then
    meta:set_string("jc_translate:enabled", "no")
    return false
  end

  return value == "yes"
end

local function save_translations_enabled(player, enabled)
  local meta = player:get_meta()

  if enabled then
    meta:set_string("jc_translate:enabled", "yes")
  else
    meta:set_string("jc_translate:enabled", "no")
  end
end

local function get_player_language_info(player)
  local name = player:get_player_name()
  local info = core.get_player_information(name)

  local lang_code = "en"

  if info and info.lang_code and info.lang_code ~= "" then
    lang_code = info.lang_code
  end

  local detected_language = normalize_language(lang_code)
  local translator_language = get_player_language(player)

  local detected_name = LANGUAGES[detected_language]
  local translator_name = LANGUAGES[translator_language]

  local matches = detected_language == translator_language

  return {
    lang_code = lang_code,
    detected_language = detected_language,
    detected_name = detected_name,
    translator_language = translator_language,
    translator_name = translator_name,
    matches = matches,
    translations_enabled = get_translations_enabled(player),
  }
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
  local translations_enabled = get_translations_enabled(player)

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
    "label[0.5,1.1;" .. escape_formspec(S("Choose Your Language:")) .. "]",
    "dropdown[0.5,1.4;7,0.8;language;", table.concat(language_list, ","), ";" .. current_index .. ";false]",
    "checkbox[0.5,2.7;enable;" .. escape_formspec(S("Enable Translations?")) .. ";" .. (translations_enabled and "true" or "false") .. "]",
    "button_exit[0.5,6.8;4,1;cancel;" .. escape_formspec(S("Cancel")) .. "]",
    "button_exit[4.8,6.8;4,1;save;" .. escape_formspec(S("Save")) .. "]",
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


local pending_translations_enabled = {}

core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "jc_translate:language" then
    return
  end

  local name = player:get_player_name()

  if fields.enable then
    pending_translations_enabled[name] = fields.enable
    core.log("action", "[" .. modname .. "] CHECKBOX: " .. name .. " fields.enable = " .. tostring(fields.enable))
    return
  end

  if fields.cancel then
    pending_translations_enabled[name] = nil
    return
  end

  if not fields.save then
    return
  end

  core.log("action", "[" .. modname .. "] SAVE: " .. name .. " pending enable = " .. tostring(pending_translations_enabled[name]))

  local selected_name = fields.language

  if not selected_name or selected_name == "" then
    core.chat_send_player(name, S("Invalid language selection."))
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
    core.chat_send_player(name, S("Invalid language selection."))
    return
  end

  local checkbox_value = pending_translations_enabled[name]

  if checkbox_value == nil then
    checkbox_value = get_translations_enabled(player) and "true" or "false"
  end

  local translations_enabled = checkbox_value == "true"

  core.log("action", "[" .. modname .. "] SAVE: " .. name .. " checkbox_value = " .. tostring(checkbox_value) .. ", translations_enabled = " .. tostring(translations_enabled))

  save_player_language(player, selected_code)
  save_translations_enabled(player, translations_enabled)

  local stored_value = player:get_meta():get_string("jc_translate:enabled")

  core.log("action", "[" .. modname .. "] SAVE: " .. name .. " stored jc_translate:enabled = " .. tostring(stored_value))

  pending_translations_enabled[name] = nil

  if translations_enabled then
    core.chat_send_player(name, S("Translation language set to @1.", S(LANGUAGES[selected_code])))
    core.chat_send_player(name, S("Translations are enabled."))
  else
    core.chat_send_player(name, S("Translations are disabled."))
  end
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

  local language_info = get_player_language_info(player)

  for _, staff in ipairs(core.get_connected_players()) do
    local staff_name = staff:get_player_name()

    if core.check_player_privs(staff_name, {ban = true}) then
      local client_language

      if language_info.detected_name then
        client_language = language_info.detected_name .. " (" .. language_info.lang_code .. ")"
      else
        client_language = language_info.lang_code
      end

      local translator_language

      if language_info.translator_name then
        translator_language = language_info.translator_name .. " (" .. language_info.translator_language .. ")"
      else
        translator_language = language_info.translator_language
      end

      local match_text

      if language_info.matches then
        match_text = S("YES")
      else
        match_text = S("NO")
      end

      local translation_status

      if language_info.translations_enabled then
        translation_status = S("YES")
      else
        translation_status = S("NO")
      end

      core.chat_send_player(
        staff_name,
        core.colorize(
          "#00FF00",
          S(
            "*** LANGUAGE: @1 is using @2. Translator language: @3. Matches client language: @4. Translations enabled: @5.",
            name,
            client_language,
            translator_language,
            match_text,
            translation_status
          )
        )
      )
    end
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

local function escape_html(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  text = text:gsub('"', "&quot;")
  text = text:gsub("'", "&#39;")

  return text
end

local function protect_urls_and_usernames(text)
  text = escape_html(text)

  -- Protect URLs first.
  text = text:gsub(
    "https?://[%w%-%._~:/%?#%[%]@!$&'()*+,;=%%]+",
    function(url)
      return '<span translate="no">' .. url .. '</span>'
    end
  )

  local names = {}

  for _, player in ipairs(core.get_connected_players()) do
    local name = player:get_player_name()

    if name ~= "" then
      table.insert(names, name)
    end
  end

  table.sort(names, function(a, b)
    return #a > #b
  end)

  for _, name in ipairs(names) do
    local escaped_name = escape_html(name)

    escaped_name = escaped_name:gsub(
      "([%%%^%$%(%)%.%[%]%*%+%-%?])",
      "%%%1"
    )

    -- Protect the username and punctuation immediately following it.
    text = text:gsub(
      "(" .. escaped_name .. ")([,%.!%?:;]?)",
      function(username, punctuation)
        return '<span translate="no">'
          .. username
          .. punctuation
          .. '</span>'
      end
    )
  end

  return text
end


local function remove_translate_no_spans(text)
  text = text:gsub('<span%s+translate%s*=%s*"no"%s*>(.-)</span>', "%1" )
  text = text .. " "

  return text
end

local function translate_text(text, source_language, target_language, callback)
  if source_language == target_language then
    callback(text)
    return
  end

  local protected_text = protect_urls_and_usernames(text)

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
    format = "html",
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

    local restored = remove_translate_no_spans(data.translatedText)

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
    local translations_enabled = get_translations_enabled(player)

    recipients[recipient_name] = {
      language = target_language,
      translations_enabled = translations_enabled,
    }

    if translations_enabled then
      languages_needed[target_language] = true
    end
  end

  local prefix = get_chat_prefix(name)
  local prefix_text = get_chat_prefix_text(name)

  -- Log the original message exactly as typed.
  core.log("action", "CHAT: " .. prefix_text .. "<" .. name .. "> " .. message)

  -- Send the original message immediately to players
  -- who have translations disabled.
  for recipient_name, recipient in pairs(recipients) do
    if not recipient.translations_enabled then
      core.chat_send_player(recipient_name, prefix .. "<" .. name .. "> " .. message )
    elseif recipient.language == source_language then
      -- Same language does not require translation.
      core.chat_send_player(recipient_name, prefix .. "<" .. name .. "> " .. message )
    end
  end

  -- Translate once per required target language.
  for target_language in pairs(languages_needed) do
    if target_language ~= source_language then

      translate_text(
        message,
        source_language,
        target_language,
        function(result)

          local output = result or message

          if not result then
            core.log("warning", "[" .. modname .. "] Translation failed: " .. source_language .. " -> " .. target_language )
          end

          -- Send this translation immediately to everyone
          -- who has translations enabled and uses this language.
          for recipient_name, recipient in pairs(recipients) do
            if recipient.translations_enabled and recipient.language == target_language then
              core.chat_send_player(recipient_name, prefix .. "<" .. name .. "> " .. output)
            end
          end
        end
      )
    end
  end

  return true
end)