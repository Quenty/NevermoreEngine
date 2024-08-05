## Snackbar
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

Snackbars provide lightweight feedback on an operation at the base of the screen. They automatically disappear after a timeout or user interaction. There can only be one on the screen at a time.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/SnackbarServiceClient">View docs →</a></div>

## Installation
```
npm install @quenty/snackbar --save
```

## Usage
Using the snackbar should be done via the SnackbarManager, which ensures only one snackbar can be visible at a time.

```lua
local snackbarServiceClient = serviceBag:GetService(SnackbarServiceClient)

snackbarServiceClient:ShowSnackbar("Settings saved!", {
  CallToAction = {
    Text = "Undo";
    OnClick = function()
      print("Activated action")
    end;
  }
})
```