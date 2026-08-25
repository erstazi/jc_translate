# jc_translate

A multilingual chat translation mod for Luanti.

jc_translate automatically translates player chat messages into each
player's selected language. Players can choose their preferred language
using the /lang command.

The mod uses LibreTranslate as the translation service. jc_translate does
not provide or host a LibreTranslate server. Server administrators must
provide their own LibreTranslate instance or use a LibreTranslate service
that they have access to.

# LibreTranslate

LibreTranslate is an open-source machine translation API. LibreTranslate
is responsible for performing the actual translation; jc_translate only
sends the chat text to the configured LibreTranslate API and delivers the
translated result to players.

LibreTranslate setup, installation, hosting, supported languages, API
configuration, API keys, usage limits, and other LibreTranslate-specific
questions are outside the scope of this README.

For information about LibreTranslate, visit:

https://libretranslate.com/

Documentation:

https://docs.libretranslate.com/

# Configuration

Add the following settings to your minetest.conf:

jc_translate.api_url = <LibreTranslate API URL>
jc_translate.api_key = <LibreTranslate API key>
jc_translate.timeout = 10.0

## Settings

jc_translate.api_url
LibreTranslate API URL.

```
This should point to the API endpoint provided by your LibreTranslate
instance.

Type: string
```

jc_translate.api_key
LibreTranslate API key.

```
This is the API key used by jc_translate when making translation
requests.

Type: string
```

jc_translate.timeout
Maximum amount of time jc_translate will wait for a LibreTranslate
request.

```
Type: float

Default: 10.0 seconds
```

# Example

jc_translate.api_url = https://your-libretranslate-server.example.com/translate
jc_translate.api_key = YOUR_API_KEY
jc_translate.timeout = 10.0

IMPORTANT: Replace the example URL and API key with the values for your
own LibreTranslate instance.

# Security

Keep your LibreTranslate API key private.

Do not publish your API key in a public repository or distribute it with
the mod. The API key should be configured by the server administrator in
the server's minetest.conf.

# HTTP Access

jc_translate requires access to the configured LibreTranslate API through
Luanti's HTTP API.

The mod must be allowed to access the configured HTTP service through
Luanti's secure HTTP configuration.

For example, the mod may need to be added to:

secure.http_mods = jc_translate

in minetest.conf, depending on the Luanti version and server configuration.

# Player Languages

Players can use:

/lang

to open the language selection menu.

The mod automatically detects a player's client language when they first
join. Players can then manually select a different translation language
using /lang.

The selected language is stored in player metadata and is preserved when
the player leaves and rejoins the server.

# Chat Translation

When a player sends a chat message, jc_translate determines the language
selected by each connected player.

If a recipient uses the same language as the sender, the original message
is sent without using LibreTranslate.

If a recipient uses a different language, jc_translate requests a
translation from LibreTranslate and sends the translated message to that
recipient.

Different target languages are translated separately so that each player
receives chat in their selected language.

# Usernames

jc_translate attempts to protect the usernames of currently connected
players from being translated.

Player names found inside chat messages are temporarily replaced with
special placeholders before the message is sent to LibreTranslate.
After translation, the placeholders are replaced with the original
usernames.

For example:

```
Hello PlayerNameJoe, can you help PlayerNameSam?
```

may be sent to LibreTranslate approximately as:

```
Hello ZXQP1ZXQ, can you help ZXQP2ZXQ?
```

The usernames are then restored after translation.

The sender's username is also kept outside the translated message header.

# Ranks

If the ranks mod is installed and provides the expected ranks API,
jc_translate can display the player's rank prefix in chat.

jc_translate does not require the ranks mod to perform translation.

If ranks is not installed, chat messages are displayed without a rank
prefix.

# Logging

jc_translate logs chat messages using Luanti's action log.

Chat is logged in the following general format:

```
CHAT: <player> message
```

If a player has a rank with a configured prefix_text, that prefix is
included in the log entry.

Translation failures are logged as warnings.

# Requirements

* Luanti
* A working LibreTranslate API
* A valid LibreTranslate API key, if required by the configured service
* Luanti HTTP access enabled for jc_translate

# License

See the LICENSE file included with this mod, if present.

# LibreTranslate Information

jc_translate is a client of the LibreTranslate API and is not a
replacement for LibreTranslate.

For LibreTranslate installation, hosting, API usage, supported languages,
configuration, authentication, and other LibreTranslate-specific
information, please consult the official LibreTranslate resources:

Website:
https://libretranslate.com/

Documentation:
https://docs.libretranslate.com/

LibreTranslate setup and operation are intentionally outside the scope
of this README.
