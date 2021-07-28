## HttpPromise
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/lint/badge.svg" alt="Actions Status" />
  </a>
</div>

HttpPromise - Wrapper functions around http requests in Roblox.

## Installation
```
npm install @quenty/httppromise --save
```

## Usage

```lua
-- Make a request
local requestPromise = HttpPromise.request({
	Headers = {
		["Content-Type"] = "application/json";
	};
	Url = DISCORD_LOG_URL;
	Body = HttpService:JSONEncode(data);
	Method = "POST";
})

```

### Decoding JSON
```lua
-- Decode JSON results
requestPromise = requestPromise
	:Then(HttpPromise.decodeJson)
```

### Logging failed results
```lua
-- Log failed results
requestPromise = requestPromise
	:Catch(HttpPromise.logFailedRequests)

```

### Generic request
By combining functions in HttpPromise, we can get a generic request result in a very clean way.

```lua
-- All together now!

local function logToDiscord(body)
	return HttpPromise.request({
		Headers = {
			["Content-Type"] = "application/json";
		};
		Url = DISCORD_LOG_URL;
		Body = HttpService:JSONEncode(data);
		Method = "POST";
	})
	:Then(HttpPromise.decodeJson)
	:Catch(HttpPromise.logFailedRequests)
end
```

## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit