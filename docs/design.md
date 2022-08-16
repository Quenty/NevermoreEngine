---
sidebar_position: 2
---

# Design philosophy

Nevermore consists of a few hundred packages in a mono-repo. These packages are [semantically versioned](https://semver.org/) such that long-term maintaince can be done.

# Design criteria

Nevermore has been evolving for a long time. As Roblox has improved its platform capabilities, parts of Nevermore have become unneeded, while new parts are necessary to keep
things working. Nevermore is a repository of useful generalized modules that can be used to make games quicker. Note these modules while opinionated to some level, try to not be
opinionated about...

1. Your games architecture
2. Consumption of code (plugin, game, et cetera)

Code is designed to be copied and pasted as needed, but first and foremost, is designed to empower James's (Quenty's) workflow. For this reason, while Nevermore tries its best to be useful
to as wide of an audience as possible, in many ways document and design notes are lacking because this is not its first purpose.


# Loading system

Nevermore's loading system has changed over time, but is generally responsible for loading many modules.
