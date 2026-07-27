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

You can build all of this out of Rx chains, and most games already have. Ownership feeds a
`combineLatest`, a flag guards it, a subscription somewhere kicks people. It works right up until
somebody says *"I can't get in"* — and then you are reading four files trying to reconstruct which
input was false at the time.

This package is not more powerful than the chains it replaces. It is the same logic with two things
the chains do not give you:

**Instrumentation.** Every input is named, addressable, inspectable and overridable. One console
command prints the whole decision — every layer, what each said, which one won — and the same
computation produces both the answer and the explanation, so a readout can never describe a decision
that was not the one made.

**Legibility.** A named vocabulary means the shape of an access rule is readable without tracing it.
`kick-on-non-admin reads playerIsAdmin` says more than any chain of operators can.

The cost is a little ceremony. The return is that access stops being the part of the codebase nobody
wants to touch.

## Vocabulary

Three kinds of thing, split so each can be reasoned about on its own terms. That separation is the
whole design, and it is worth being explicit about *why* each one is separate.

**Facts** state what is true. *Does this player own the game. Is the event running. Is this player
staff.* Facts include things that sound like switches — whether an event is running is a fact about the
world — but a fact never **decides** anything: it does not combine other facts into a verdict and never
reasons about what its answer is for. That restraint is what makes them **easy to test**: one lookup,
one answer, so the test is "given this stream, assert true, false or unresolved" — no policy, no realms,
no game state.

**Features** are capabilities a game gates. *May this player enter a chapter.* Features **decide** —
every judgement lives here, and this is where the **release schedule** sits: which combination of facts
opens a thing, and when. `ownsGame` grants
`chapters` only once the game has launched, but always denies `gamePurchase`, because "we have not
opened yet" is no reason to sell someone a game they already own. Keeping that here means flipping a
launch is a change to one feature rather than a hunt through every surface that asks.

**Policies** are consequences — the parts with **side effects on the real game**. *Kick anyone who is
not staff.* Policies are the only kind that *do* anything, which is why they are the only kind that
ships **disabled**, that declares its inputs, and that has a lifetime you can end.

The three-way split is a convenience, not a law. A fact may aggregate other facts; a feature may be
trivial; where a rule belongs is sometimes a judgement call. What the split buys is that when
something is wrong you know which of three questions you are asking: *is the input wrong* (fact), *is
the rule wrong* (feature), or *is the reaction wrong* (policy). Those are debugged very differently,
and a single Rx chain makes you answer all three at once.

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
| `access-state <players> [server\|client\|both]` | everything: every feature verdict, every policy, every fact |
| `access-facts <players>` | every fact with its layers and which one decided |
| `access-feature <players> <feature>` | one verdict and the facts it was reached from |
| `access-override <players> <fact> <true\|false\|unresolved>` | force a fact, including forcing *unresolved* |
| `access-policies` | every policy and whether it is running |
| `access-policy <policy> <on\|off>` | turn a consequence on or off |

Every command is admin-gated by `CmdrService`. Overrides appear as their own layer with the real answer
still visible underneath, so nobody mistakes one left on after a QA session for a genuine entitlement.

`access-state ... both` asks the player's own client what *it* resolved and prints it beside the server's
view. Both blocks come from one collector, so a difference between them is a real difference and not two
readouts phrased differently — which is the failure this package exists to make visible. The client's
answer is a readout only and never feeds a decision; a client that could report its own access
authoritatively could grant itself whatever it liked.

## Consuming from another package

Reach the service through its tie rather than by depending on this package, and read `nil` in a game
that doesn't have it:

```lua
local access = AccessDataServiceInterface:Find(ReplicatedStorage)
if access then
	access:ObserveIsFeatureAllowedByName(player, "owns-game"):Subscribe(...)
end
```
