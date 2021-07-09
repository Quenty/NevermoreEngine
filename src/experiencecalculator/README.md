## ExperienceCalculator
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

Calculate experience on an exponential curve and perform relevant calculations Uses formulas from stackoverflow.com/questions/6954874/php-game-formula-to-calculate-a-level-based-on-exp

## Installation
```
npm install @quenty/experiencecalculator --save
```

## Usage
Usage is designed to be simple.

### `ExperienceCalculator.setExperienceFactor(factor)`

### `ExperienceCalculator.getLevel(experience)`
Gets the current level from experience

### `ExperienceCalculator.getExperienceRequiredForNextLevel(currentLevel)`
Given a current level, return the experience required for the next one

### `ExperienceCalculator.getExperienceRequiredForLevel(level)`
Gets experience required for a current level

### `ExperienceCalculator.getExperienceForNextLevel(currentExperience)`
Gets experience left to earn required for next level

### `ExperienceCalculator.getSubExperience(currentExperience)`
Calculates subtotal experience

