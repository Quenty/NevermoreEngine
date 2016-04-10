# TrelloErrorLogger
This module is for automatically logging errors with a Trello Board. Credit to [YonaJune](https://scriptinghelpers.org/user/8/YonaJune) for [original](https://scriptinghelpers.org/blog/logging-errors-with-trello).

To set up, first you are going to want to create a new board on [Trello](https://trello.com/).
![](http://i.imgur.com/FqaPhTm.png)

Name it whatever you like, but make sure your board is set to **public**
![](http://i.imgur.com/KbA8Klr.png)

Next, go to [this link](https://trello.com/app-key) and replace YOUR_KEY in the following link with your given Key

``https://trello.com/1/authorize?key=YOUR_KEY&name=ROBLOXErrors&expiration=never&response_type=token&scope=read,write``

![](http://i.imgur.com/xwcDx5R.png)



<h3>TrelloErrorLogger should be called like so:</h3>

**Server:**
Replace the following with [your information](https://trello.com/app-key):
![](http://i.imgur.com/9xqynfZ.png)
```lua
local TrelloErrorLogger	= LoadCustomLibrary("TrelloErrorLogger"){
	trelloUsername		= "Narrev";
	boardName			= "Roblox Error Logs";
	listName			= "Errors";
	key					= "54b8fe02d0ecafa8eaca8a783d85d0bd";
	secret				= "e94ad36cb37e2d2d006637714f3a216d19d1ada096073e250be45ec96930ccce";
}
```

**Client:**
```lua
local TrelloErrorLogger = LoadCustomLibrary("TrelloErrorLogger")
```
