## DataStore
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

This system is a reliable datastore system designed with promises and asyncronious code in mind, and has been tested on several games. Underlying this system are several key design points.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/DataStore">View docs →</a></div>

## Executive overiew
This datastore prevents data loss by being explicit about what we're writing to, and only modifying the data that exists there instead of modifying the whole structure.

## How syncing works
Sometimes datastores (like a global game data store) need to be synced live instead of upon server or player start. This is if we expect multiple servers to write to the same datastore at once we can use thie sync method to 

Syncing is like saving. However, instead of treating the current datastore as a session lock, we load in additional data from our "source-of-truth". From here, we merge that data into the datastore, which means both clearing any matching write tokens that our sync says is done. 

This is best for a "shared" memory that can be temporarily not correct. Deleting with a sync is less effective.


## Installation
```
npm install @quenty/datastore --save
```

* Minimize usage of the read and write datastore APIs so that API limits can be safely used
	* This means combining several datastore entries into one store. Instead of having 1 entry for gold, and 1 entry for money, this system combines the overall entries together into a table, while providing an API that is acceptable to use and acts as if you had entries for each one.
	* Furthermore, abstracting this API so that dependences aren't required
* Detect load failures and prevent further
* Deal with the fundamental asyncronious component of DataStores
* Abstract away a dependence upon faulty datastore API such that you can reasonable deal with errors
* Ability to move from legacy system to this system
* Proper merging on substores and systems
* Proper write/change detection to minimize API calls
* Granular control on exactly what happens, including load process

For this reason, this system relies heavily on Promises. The public facing API in question that is interesting is:

### PlayerDataStoreManager
This class provides data for Roblox players. It includes the following features:

* Arbitrary key generation allows for moving legacy datastores to this new API
* Autosaving on player leave
* Autosaving on game close
* Autosaving at a set length

This helps manage the life-cycle of Roblox datastores for a player, and preventing unnecessary API calls.

Usage looks like this:

```lua
local dataStoreManager = PlayerDataStoreManager.new(
	DataStoreService:GetDataStore("PlayerData", "Version_1"), --  Load the base Roblox store however you want
	function(player)
		return tostring(player.UserId)
	end)
```

Once you have a copy constructed, there are only a few APIs that you might consider

* `dataStoreManager:DisableSaveOnCloseStudio()` - Prevents saving on close in studio, thus, allowing faster iteration times
* `dataStoreManager:GetDataStore(robloxPlayer)` - Retrieves a datastore for a player. You can write/read from this datastore immediately.

### DataStore.lua
This class wraps a single datastore key in a Roblox datastore, and can be used to store as many components as wanted. This component does
nothing until it is invoked. This is useful when you have data not associated with any player. Datastores have the following abilities

* Loading values with a default value
* Autosaving values from a Roblox `ValueObject`
* Ability to write "chunks" i.e. tables
* Detection of if data has changed -- if it hasn't,
* No arbitrary deletion of data -- proper merging
* Proper write/change detection to minimize API calls
* Ability to retrieve "substores" in an entry
* Ability to detect load/fail success

The datastore basically is storing a table. You can query these keys using APIs.

Constructing a new datastore looks like this:
```lua
local dataStore = DataStore.new(robloxDataStore, key)
```
Once a datastore is constructed there are many things you can do with it.

#### Basic store and load API

* `dataStore:Load(keyName, defaultValue)` - Returns a promise, that loads from the datastore and reads that value as a key. Multiple calls to this will reuse the same cached promise.

```lua
dataStore:Load("money", 0):Then(function(money)
	playerMoneyValue.Value = money
	-- TODO: Enable saving here, but not before
end):Catch(function()
	-- TODO: Notify player
end)
```

Here promises are used to asycroniously load the state. You should generally try to prevent loading if the player has already left. You can utilize maids to do this:

```lua
maid:GivePromise(dataStore:Load("money", 0)):Then(function(money)
	-- If the maid cleans up before the promise occurs, then you won't load the playerMoneyValue
	playerMoneyValue.Value = money
	-- TODO: Enable saving here, but not before
end):Catch(function()
	-- TODO: Notify player if still in game
end)
```

Note that additionaly loads will retrieve the value of stored values, which means that overall datastores can fail to load, but if you store a value, it will resolve to success.

For example...

```lua
dataStore:Store("money", 5)
dataStore:Load("money", 0):Then(function(value)
	print(value) -> 5
end)
```

This will never error, even if datastores are down. It's VITAL that you don't store until you've loaded the values if you want to handle this sort of edge case successfully. Otherwise, players will have bad values loaded in, and you'll drop their data. So in this case, players will get 5 as their money, instead of what
the store actually has.

* `dataStore:Store(keyName, value)` - Stores that value, overwriting the existing value. Returns nothing. On subsequent loads this value will be retrieved.

!!! important
	It's vital that you only store after you're certain you've loaded values into the game. Otherwise you might wipe players data. The good news is the API was designed with this in mind! However, you have full control of this process!

Note that passing in `nil` to this value is the equivalent of `dataStore:Delete(keyName)`. You can also pass in `DataStoreDeleteToken` to force a delete.

Note this will not guarantee a flush to Roblox's datastore. If you're using the PlayerDataStoreManager then it will automatically handle it. Otherwise, you'll need to call :Save(). However, it's suggested that you batch changes, and then flush to the store all at once.

Usage:
```lua
dataStore:Store("money", playerMoneyValue.Value) -- Stores the current value in the store
```

* `dataStore:StoreOnValueChange(name, valueObj)` - Stores with the key `name` when the `valueObj` changes. This allows you to easily setup saving on ValueObjects as the primary storage system. Returns a connection which you should give to your maid, if possible

!!! important
	It's vital that you only enable saving after you're certain you've loaded the value into the game. Otherwise you might wipe players data. The good news is the API was designed with this in mind!

Basic usage without maids:
```lua
dataStore:Load("money", 0):Then(function(money)
	-- If the maid cleans up before the promise occurs, then you won't load the playerMoneyValue
	playerMoneyValue.Value = money

	-- Enable saving after we're certain we've loaded:
	dataStore:StoreOnValueChange("money", playerMoneyValue)
end):Catch(function()
	-- TODO: Notify player if still in game
	-- Note: we didn't enable saving because datastores are down
end)
```

Basic usage with maids. This is a much "safer" way to make sure you garbage collect things properly, but you must understand how maids work.
```lua
maid:GivePromise(dataStore:Load("money", 0)):Then(function(money)
	-- If the maid cleans up before the promise occurs, then you won't load the playerMoneyValue
	playerMoneyValue.Value = money

	-- Enable saving after we're certain we've loaded:
	maid:GiveTask(dataStore:StoreOnValueChange("money", playerMoneyValue))
end):Catch(function()
	-- TODO: Notify player if still in game
	-- Note: we didn't enable saving because datastores are down
end)
```

* `dataStore:Delete(keyName)` - Deletes a value from the store. This overwrites the exising value. This returns nothing. Note you still need to :Save()/flush the datastore for this to occur.

```lua
dataStore:Delete("money") -- Deletes the current money key on the next time :Save() is called.
```

* `dataStore:HasWritableData()` - Returns true or false, if there's writable data that needs to be flushed to the datastore system.

Sample usage:
```lua
if dataStore:HasWritableData() then
	dataStore:Save():Then(function()
		print("Saved")
	end):Catch(function()
		print("Didn't save!")
	end)
end
```


#### Substores
Many times you want your data to be organized in a more reasonable way. For example, players might want to have multiple save slots, but you still only want to use
one key. Additionally, you want to avoid namespace collisions in your datastore.

A primary feature of this datastore system is the Substores. These are tables stored within the primary table.

* `dataStore:GetSubStore(name)` - Retrieves a new substore. This has all the API as the `DataStore` class specified above.

Usage:

```lua
local dataStore = playerDataStoreManager:GetDataStore(player)

-- Let's use a substore here so we can add slots later
local currentSlot = dataStore:GetSubStore("slot0")
local playerData = currentSlot:GetSubStore("data")

playerData:Load("money", 0):Then(function(money)
	playerMoneyValue.Value = money
	playerData:StoreOnValueChange("money", playerMoneyValue) -- Enable saving now that we've loaded in
end):Catch(function(err)
	warn("Failed to load data store")
end)

```

For legacy systems you can utilize this to retrieve subtables. So if this is the top level datastore, in the above example, you'd get a structure like this:

```
Output from above example:

{
	slot0 = {
		data = {
			money = 0;
		};
	};
}

```

Note that substores can be utilized next to existing data. For example, you can do this:

```lua
local dataStore = playerDataStoreManager:GetDataStore(player)

-- Let's use a substore here so we can add slots later
local currentSlot = dataStore:GetSubStore("slot0")
local playerData = currentSlot:GetSubStore("data")

playerData:Load("money", 0):Then(function(money)
	playerMoneyValue.Value = money
	playerData:StoreOnValueChange("money", playerMoneyValue) -- Enable saving
end):Catch(function(err)
	warn("Failed to lood data store")
end)

-- Track play times
dataStore:Load("playTimes", 0):Then(function(playTimes)
	dataStore:Store("playTimes", playTimes + 1)
end)
```

This results in a save structure like this:

```
Output from above example:

{
	slot0 = {
		data = {
			money = 0;
		};
	};
	playTimes = 1;
}

```

#### Forcing a save / managing load cycle
* `dataStore:Save()` - Forces a save of all data, and returns a promise that will resolve on success.

If you're using the PlayerDataStoreManager then this isn't necessary and does not have to be called, even if you're teleporting players.

Note this actually flushes the datastore to the datastore. You do not need to call this after writing everytime. Rather, you should use this when you're
ready to flush the store back into the actual Roblox datastore.

Usage:
```lua
-- Note: Unnecessary with PlayerDataStoreManager datastores, it will autosave. :D
dataStore:Save():Then(function()
	print("Datastore saved successfully")
end):Catch(function(err)
	warn("Failed to save", err)
	-- TODO: Notify player
end)
```

Note that this will only flush data that has been written. So if you only write to the money value, it will only overwrite that value. This helps prevent large losses of
data when thigns get weird.

Note that this means that data not flagged for deletion will not be wiped.

#### Detecting load failures and success

* `dataStore:PromiseLoadSuccessful()` - Returns a promise that will resolve upon load success, and be rejected upon failure.

You can use it like this:
```lua
dataStore:PromiseLoadSuccessful():Then(function()
	-- Maybe enable some saving here/notify player? Generally you should enable saving when you actually load the value.
end):Catch(function(err)
	-- Notify player that datastores are down.
end)
```

* `dataStore:DidLoadFail()` If the load has failed at any point, this will return true

## Additional utilities

There is an additional utility class that is `DataStorePromises`. These can be used without the regular API system if you need quick access.

Finally, DataStore's have a Saving signal you can listen to. Note that this only exists on the top-level datastore, and substores do not have a notion of being
flushed to Roblox's datastore system.

```lua
dataStore.Saving:Connect(function(savingFinishedPromise)
	print("Svaing to Roblox DataStore")
	savingFinishedPromise:Then(function()
		print("Done flushing save to the Roblox Datastore")
	end):Catch(function()
		print("Failed to flush to Roblox datastore")
	end)
end)
```

## Debugging storing behavior
You can see what is actually being saved to Roblox by turning on the flag `DEBUG_WRITING = true` in the DataStore.lua file.

## Sample working code

This is done in one file to simplify behavior. I recommend you use modules in general to handle this. However, this should structually be a usage of the datastore to load and save a simple money value automatically.

THIS CODE IS UNTESTED, LET ME KNOW IF IT BREAKS: :D

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataStoreManager = require("PlayerDataStoreManager")

local dataStoreManager = PlayerDataStoreManager.new(
	DataStoreService:GetDataStore("PlayerData", "Version_1"), --  Load the base Roblox store however you want
	function(player)
		return tostring(player.UserId)
	end)

-- Note how we don't care what part of the player's data we use? Substores FTW. :D
local function loadStats(slotStore)
	local leaderboard = Instance.new("Folder")
	leaderboard.Name = "leaderstats"

	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "money"
	moneyValue.Value = 0
	moneyValue.Parent = leaderboard

	slotStore:Load("money", 0):Then(function(money)
		moneyValue.Value = money
		slotStore:StoreOnValueChange("money", moneyValue)
	end):Catch(function(...)
		warn("Failed to load", ...)
	end)

	return leaderboard
end

local function handlePlayerAdded(player)
	local dataStore = dataStoreManager:GetDataStore(player)
	local slotStore = dataStore:GetSubStore("slot0")

	local leaderboard = loadStats(slotStore)
	leaderboard.Parent = player
end


-- Do actual load

Players.PlayerAdded:Connect(handlePlayerAdded)
for _, player in pairs(Players:GetPlayers()) do
	handlePlayerAdded(player)
end
```
