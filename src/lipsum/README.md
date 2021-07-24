## Lorem Ipsum Generator
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

Lorem ipsum generator for Roblox. This package is designed to help with debugging!

## Installation
```
npm install @quenty/lispum --save
```

## Usage
Usage is designed to be very simple.

### Usernames
```lua
print(LipsumUtils.username()) --> LoremIpsum23
```

### Words
```lua
print(LipsumUtils.words(5)) --> 5 words
```

### Sentences
```lua
print(LipsumUtils.sentence(7)) --> Sentence with 7 words.
```

### Paragraphs
```lua
print(LipsumUtils.paragraph(4)) --> Paragraph with 4 sentences.
```

### Documents
```lua
print(LipsumUtils.document(3)) --> Document with 3 paragraphs
```
## Changelog

### 0.0.1
Added documentation

### 0.0.0
Initial commit