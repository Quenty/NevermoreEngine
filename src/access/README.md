## Access

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

Feature access gating: facts about a player, features that decide

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/AccessUtils">View docs →</a></div>

## Installation

```
npm install @quenty/access --save
```

## Why this exists

Access questions get answered in more than one place. The menu decides whether to show a button, the
storefront decides whether to offer a purchase, and the server decides whether to let someone in — and
each one grows its own copy of the rule. They drift, and the drift is invisible until a player is stuck
in a menu that says they can play a game the server has already refused them.

This package holds one answer that every surface reads, and — just as importantly — can explain it.
When somebody says "I can't get in", one console command tells you why.

## Vocabulary

Three things, and keeping them apart is the whole design.

**Facts** are true or false about a player. *Does this player own the game.* A fact never knows what
it's for, never reads a release flag, and never consults another fact.

**Features** are capabilities a game gates. *May this player enter a chapter.* A feature reads facts and
applies policy — flags, inversions, per-thing context. The same fact can grant one feature and deny
another, which is what makes them separate: `ownsGame` grants `chapters` only after launch, but always
denies `gamePurchase`, because "we haven't opened yet" is no reason to sell someone a game they own.

**Policies** are consequences. *Kick anyone who isn't staff.* A policy reads declared facts and features
and does something about them. Policies ship **disabled** — turning one on is a deliberate act you can
see in a readout.

The boundaries are a guide, not a cage. A fact may aggregate other facts; a feature may be trivial. What
matters is that the answer stays in one place and stays explainable.

### Three answers, not two

A fact is `true`, `false`, or **unresolved** — no answer came back yet. Unresolved is deliberately not
denial, and every consumer decides what it means for itself: a storefront may offer on it; an
enforcement gate must never open on it, and must never *close* on it either. Kicking a player because a
web request hiccupped is worse than letting one linger.

## How a fact is decided

Several **layers** may answer one fact — a group rank and a staff allowlist both saying who is staff, a
console override saying so louder than either. Layers are ordered by priority, highest first, and **the
first layer that contributes decides**. A layer that abstains is skipped entirely.

Two layers of one fact must differ in priority and in source name, and registration refuses anything
else — a load-order coin toss is not something anyone can debug from a bug report.

The merge doesn't return a value, it returns a **report**: every layer, what each said, and which one
won. The value features read is a field on it, so the gate and the readout are the same computation and
a readout can never explain a decision that wasn't the one made.

```
> access-facts Quenty
Quenty
  isStaff = true (allowlist)
    override         p10000   abstained
    allowlist        p100     true       <-- decided
    groupRank        p0       false
```

## Extending rather than replacing

A feature ships reading one fact. A game adds more ways in without editing it:

```lua
local ownsGame = accessDataService:GetFeature(WellKnownAccessFeatureNames.OWNS_GAME)

maid:GiveTask(ownsGame:PushFactAllowsFeature(gamePassFact))
maid:GiveTask(ownsGame:PushFactAllowsFeature(staffFact))
```

Everything already gating on `owns-game` picks these up, including subscriptions taken out before the
push. Pushing only ever widens — a pushed fact can grant, never deny — so "add a way in" can't take one
away.

## What you can't do

There is no `ObserveFact`. Facts are addressable so they can be inspected and overridden, but you cannot
subscribe to one and write your own rule at a call site. That asymmetry is what keeps every consumer
reading the same verdict, which is the entire reason this is a package rather than four call sites that
each decide for themselves.

Policies are the exception, and only because they're registered, named, and declare their inputs — so
what a policy reads shows up in a readout like everything else.

## Console

| Command | |
| --- | --- |
| `access-state <players>` | everything: every feature verdict, every policy, every fact |
| `access-facts <players>` | every fact with its layers and which one decided |
| `access-feature <players> <feature>` | one verdict and the facts it was reached from |
| `access-override <players> <fact> <true\|false\|unresolved>` | force a fact, including forcing *unresolved* |
| `access-policies` | every policy and whether it is running |
| `access-policy <policy> <on\|off>` | turn a consequence on or off |

Every command is admin-gated by `CmdrService`. Overrides appear as their own layer with the real answer
still visible underneath, so nobody mistakes one left on after a QA session for a genuine entitlement.

## Consuming from another package

Reach the service through its tie rather than by depending on this package, and read `nil` in a game
that doesn't have it:

```lua
local access = AccessDataServiceInterface:Find(ReplicatedStorage)
if access then
	access:ObserveIsFeatureAllowedByName(player, "owns-game"):Subscribe(...)
end
```
