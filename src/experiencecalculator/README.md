## ExperienceCalculator
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
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


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit