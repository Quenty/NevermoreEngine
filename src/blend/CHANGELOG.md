# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [12.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@12.2.0...@quenty/blend@12.3.0) (2024-05-09)


### Bug Fixes

* Bootstrap specifically to loader ([7f4d4f9](https://github.com/Quenty/NevermoreEngine/commit/7f4d4f9cd4a6602af8daaf04983bb349dafc7e95))
* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))


### Features

* Still allow spring objects to work on server ([65cadaf](https://github.com/Quenty/NevermoreEngine/commit/65cadafc84015294b4946f1d4cae228a9a7786e2))





# [12.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@12.1.1...@quenty/blend@12.2.0) (2024-04-27)

**Note:** Version bump only for package @quenty/blend





## [12.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@12.1.0...@quenty/blend@12.1.1) (2024-04-23)

**Note:** Version bump only for package @quenty/blend





# [12.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@12.0.0...@quenty/blend@12.1.0) (2024-03-09)


### Bug Fixes

* SetTarget properly in SpringObject ([94358e6](https://github.com/Quenty/NevermoreEngine/commit/94358e6d3cda41a0ecc65672ca21ae1efa13aa4e))





# [12.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@11.0.0...@quenty/blend@12.0.0) (2024-02-14)

**Note:** Version bump only for package @quenty/blend





# [11.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@10.0.0...@quenty/blend@11.0.0) (2024-02-13)


### Bug Fixes

* Fix bootstrap of test environments and loader samples ([441e4a9](https://github.com/Quenty/NevermoreEngine/commit/441e4a90d19fcc203da2fdedc08e532c20d52f99))





# [10.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@9.0.0...@quenty/blend@10.0.0) (2024-02-13)

**Note:** Version bump only for package @quenty/blend





# [9.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@8.0.0...@quenty/blend@9.0.0) (2024-02-13)


### Features

* New loader (breaking changes), fixing loader issues  ([#439](https://github.com/Quenty/NevermoreEngine/issues/439)) ([3534345](https://github.com/Quenty/NevermoreEngine/commit/353434522918812953bd9f13fece73e27a4d034d))


### BREAKING CHANGES

* Standard loader

Adds new loader version which replicates full structure instead of some partial structure. This allows us to have hot-reloading (in the future), as well as generally do less computation, handle dependencies more carefully, and other changes.

This means you'll need to change you how require client-side modules, as we export a simple `loader` module instead of all modules available.

Signed-off-by: James Onnen <jonnen0@gmail.com>

* fix: Fix missing dependency in ResetService

* feat: Add RxPhysicsUtils.observePartMass

* fix: Fix package discovery for games

* feat: Add UIAlignmentUtils.verticalToHorizontalAlignment(verticalAlignment) and UIAlignmentUtils.horizontalToVerticalAlignment(horizontalAlignment)

* feat: AdorneeData:InitAttributes() does not require data as a  secondparameter

* ci: Upgrade to new rojo 7.4.0

* fix: Update loader to handle hoarcekat properly

* docs: Fix spacing in Maid

* fix: Add new ragdoll constants

* fix: Compress influxDB sends

* style: Errors use string.format

* fix: Handle motor animations

* ci: Upgrade rojo version

* feat!: Maid no longer is includd in ValueObject.Changed event

* docs: Fix docs





# [8.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.4.0...@quenty/blend@8.0.0) (2024-01-10)

**Note:** Version bump only for package @quenty/blend





# [7.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.3.0...@quenty/blend@7.4.0) (2024-01-08)


### Bug Fixes

* SpringObject transfers clock properly ([b47b91c](https://github.com/Quenty/NevermoreEngine/commit/b47b91cfc7d4aea2bb715744730a1fcc4c397868))





# [7.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.2.0...@quenty/blend@7.3.0) (2023-12-28)

**Note:** Version bump only for package @quenty/blend





# [7.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.1.1...@quenty/blend@7.2.0) (2023-12-14)


### Bug Fixes

* SpringObject has better errors ([ff78f35](https://github.com/Quenty/NevermoreEngine/commit/ff78f359dfab564a27b363c47edb9415138e7185))
* Update default props to be enums, and smooth top and bottom surfaces of parts ([6036177](https://github.com/Quenty/NevermoreEngine/commit/60361779332eb6f04575c9c654c9d3d6440d3d1c))





## [7.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.1.0...@quenty/blend@7.1.1) (2023-10-28)

**Note:** Version bump only for package @quenty/blend





# [7.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@7.0.0...@quenty/blend@7.1.0) (2023-10-18)

**Note:** Version bump only for package @quenty/blend





# [7.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.29.0...@quenty/blend@7.0.0) (2023-10-11)


* feat!: Refactor contract for Blend.Find and add [Blend.Tags] ([ecab2ff](https://github.com/Quenty/NevermoreEngine/commit/ecab2ffc2c0da9da1bd9ee8c7edfe5dd3cf29711))


### BREAKING CHANGES

* Find now takes a class name, not a name





# [6.29.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.28.0...@quenty/blend@6.29.0) (2023-09-21)

**Note:** Version bump only for package @quenty/blend





# [6.28.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.27.0...@quenty/blend@6.28.0) (2023-09-04)

**Note:** Version bump only for package @quenty/blend





# [6.27.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.26.0...@quenty/blend@6.27.0) (2023-08-23)


### Bug Fixes

* Blend defaults sounds to inverse tapered ([ab1cac8](https://github.com/Quenty/NevermoreEngine/commit/ab1cac84faac048a6a9f3a3999f157d8987a017f))





# [6.26.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.25.0...@quenty/blend@6.26.0) (2023-08-01)

**Note:** Version bump only for package @quenty/blend





# [6.25.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.24.0...@quenty/blend@6.25.0) (2023-07-28)

**Note:** Version bump only for package @quenty/blend





# [6.24.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.23.0...@quenty/blend@6.24.0) (2023-07-25)


### Features

* Add SpringObject:ObserveTarget() ([ff3f272](https://github.com/Quenty/NevermoreEngine/commit/ff3f2724a7776dcbcf12389767d7a62319caf63a))





# [6.23.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.22.0...@quenty/blend@6.23.0) (2023-07-23)

**Note:** Version bump only for package @quenty/blend





# [6.22.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.21.1...@quenty/blend@6.22.0) (2023-07-15)


### Features

* Add :Observe() API calls to a variety of systems and allow Blend to :Observe() stuff ([ca29c68](https://github.com/Quenty/NevermoreEngine/commit/ca29c68164dfdaf136e9168faf48f487bed26088))





## [6.21.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.21.0...@quenty/blend@6.21.1) (2023-07-11)

**Note:** Version bump only for package @quenty/blend





# [6.21.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.20.0...@quenty/blend@6.21.0) (2023-07-10)

**Note:** Version bump only for package @quenty/blend





# [6.20.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.19.0...@quenty/blend@6.20.0) (2023-06-17)

**Note:** Version bump only for package @quenty/blend





# [6.19.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.18.0...@quenty/blend@6.19.0) (2023-06-05)

**Note:** Version bump only for package @quenty/blend





# [6.18.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.17.0...@quenty/blend@6.18.0) (2023-05-26)


### Features

* Initial refactor of guis to use ValueObject instead of ValueObject ([723aba0](https://github.com/Quenty/NevermoreEngine/commit/723aba0208cae7e06c9d8bf2d8f0092d042d70ea))





# [6.17.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.16.0...@quenty/blend@6.17.0) (2023-05-08)

**Note:** Version bump only for package @quenty/blend





# [6.16.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.15.1...@quenty/blend@6.16.0) (2023-04-10)

**Note:** Version bump only for package @quenty/blend





## [6.15.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.15.0...@quenty/blend@6.15.1) (2023-04-07)

**Note:** Version bump only for package @quenty/blend





# [6.15.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.14.0...@quenty/blend@6.15.0) (2023-04-06)


### Features

* Add Blend.Find which allows mounting in existing frames, as well as allowing [Blend.Children] to be optional ([9af4998](https://github.com/Quenty/NevermoreEngine/commit/9af4998f5de3287c90f0e6eb279b95d10019bfd2))





# [6.14.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.13.0...@quenty/blend@6.14.0) (2023-04-03)

**Note:** Version bump only for package @quenty/blend





# [6.13.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.12.0...@quenty/blend@6.13.0) (2023-03-31)

**Note:** Version bump only for package @quenty/blend





# [6.12.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.11.0...@quenty/blend@6.12.0) (2023-03-31)


### Bug Fixes

* Clean up promise effectively in spring object finish ([6327d48](https://github.com/Quenty/NevermoreEngine/commit/6327d485d625554488be58efdf84d0baf406a6a1))





# [6.11.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.10.0...@quenty/blend@6.11.0) (2023-03-06)


### Features

* Add SetTarget() and Epsilon API to SpringObject ([5a60717](https://github.com/Quenty/NevermoreEngine/commit/5a607177b942a20e4679824661623a82ff296541))





# [6.10.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.9.0...@quenty/blend@6.10.0) (2023-03-05)


### Features

* Add SpringObject:PromiseFinished(signal) ([a789b24](https://github.com/Quenty/NevermoreEngine/commit/a789b2481c27d52de73ebabedee8b575f6e555b1))





# [6.9.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.8.0...@quenty/blend@6.9.0) (2023-02-27)

**Note:** Version bump only for package @quenty/blend





# [6.8.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.7.0...@quenty/blend@6.8.0) (2023-02-21)

**Note:** Version bump only for package @quenty/blend





# [6.7.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.6.0...@quenty/blend@6.7.0) (2023-01-11)

**Note:** Version bump only for package @quenty/blend





# [6.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.5.1...@quenty/blend@6.6.0) (2023-01-01)

**Note:** Version bump only for package @quenty/blend





## [6.5.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.5.0...@quenty/blend@6.5.1) (2022-12-27)

**Note:** Version bump only for package @quenty/blend





# [6.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.4.0...@quenty/blend@6.5.0) (2022-12-05)

**Note:** Version bump only for package @quenty/blend





# [6.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.3.1...@quenty/blend@6.4.0) (2022-11-19)

**Note:** Version bump only for package @quenty/blend





## [6.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.3.0...@quenty/blend@6.3.1) (2022-11-04)

**Note:** Version bump only for package @quenty/blend





# [6.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.2.0...@quenty/blend@6.3.0) (2022-11-04)


### Bug Fixes

* Fix setting velocity resetting position in blend spring object ([8285795](https://github.com/Quenty/NevermoreEngine/commit/8285795fb5c10305ffa7e5e5f11d6ad780d227bc))





# [6.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.1.1...@quenty/blend@6.2.0) (2022-10-23)


### Bug Fixes

* Use one less maid when mounting blend ([6451cc2](https://github.com/Quenty/NevermoreEngine/commit/6451cc27f71b6f360739f37dea754da1fea5ec04))





## [6.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.1.0...@quenty/blend@6.1.1) (2022-10-16)

**Note:** Version bump only for package @quenty/blend





# [6.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@6.0.0...@quenty/blend@6.1.0) (2022-10-11)

**Note:** Version bump only for package @quenty/blend





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@5.1.0...@quenty/blend@6.0.0) (2022-09-27)

**Note:** Version bump only for package @quenty/blend





# [5.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@5.0.1...@quenty/blend@5.1.0) (2022-08-22)

**Note:** Version bump only for package @quenty/blend





## [5.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@5.0.0...@quenty/blend@5.0.1) (2022-08-16)

**Note:** Version bump only for package @quenty/blend





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.3.1...@quenty/blend@5.0.0) (2022-08-14)


### Features

* Add Blend.Shared and Blend.Throttled to optimize expensive blend scenarios. ([3073d57](https://github.com/Quenty/NevermoreEngine/commit/3073d57e5b52ef66c03c8fcd4a7dcd61aed22fda))





## [4.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.3.0...@quenty/blend@4.3.1) (2022-08-11)

**Note:** Version bump only for package @quenty/blend





# [4.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.2.1...@quenty/blend@4.3.0) (2022-07-31)

**Note:** Version bump only for package @quenty/blend





## [4.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.2.0...@quenty/blend@4.2.1) (2022-07-19)


### Bug Fixes

* Fix broken initial value of AccelTween ([52795f6](https://github.com/Quenty/NevermoreEngine/commit/52795f6f075e763023fb85ed1eb53531381acb49))





# [4.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.1.0...@quenty/blend@4.2.0) (2022-07-02)

**Note:** Version bump only for package @quenty/blend





# [4.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@4.0.0...@quenty/blend@4.1.0) (2022-06-21)


### Bug Fixes

* Faster blend code ([ca837df](https://github.com/Quenty/NevermoreEngine/commit/ca837df52a680a00068c2e8b2e6b1bd3f25dcf9d))





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@3.2.0...@quenty/blend@4.0.0) (2022-05-21)


### Features

* Add new API to SpringObject ([7f8a41d](https://github.com/Quenty/NevermoreEngine/commit/7f8a41da6c9d07269e044bcd45493d1e14c565be))





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@3.1.0...@quenty/blend@3.2.0) (2022-03-27)

**Note:** Version bump only for package @quenty/blend





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@3.0.0...@quenty/blend@3.1.0) (2022-03-10)

**Note:** Version bump only for package @quenty/blend





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.3.0...@quenty/blend@3.0.0) (2022-03-06)


### Bug Fixes

* Instances from Blend.New are linked to lifetime of subscription without exception ([af282d2](https://github.com/Quenty/NevermoreEngine/commit/af282d264a0f06c2a94a5fd9c04ddbcb6cfbb7f1))


### Features

* Add SpringObject:IsAnimating() ([9e16f33](https://github.com/Quenty/NevermoreEngine/commit/9e16f33ebc6247f6cf65417b316485a181ce9900))





# [2.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.2.1...@quenty/blend@2.3.0) (2022-01-17)


### Features

* Add a SpringObject to blend, which is a much heavier object than a spring, but simplifies API usage significantly ([cb59db0](https://github.com/Quenty/NevermoreEngine/commit/cb59db0ed4297ecec842b0820a485e1aa0c8ad70))
* Add Blend.Attached and fix children not being unsubscribed correctly (memory leak fix) ([f4fa4c2](https://github.com/Quenty/NevermoreEngine/commit/f4fa4c2ebce9be6e16a7ab1492afaf87fe81b8aa))





## [2.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.2.0...@quenty/blend@2.2.1) (2022-01-16)

**Note:** Version bump only for package @quenty/blend





# [2.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.1.1...@quenty/blend@2.2.0) (2022-01-07)


### Bug Fixes

* Blend does not complete all observables is a sub-observable completes ([f5ce02b](https://github.com/Quenty/NevermoreEngine/commit/f5ce02bcb18003b9dd86cf9cf013cb5cc411cdcd))





## [2.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.1.0...@quenty/blend@2.1.1) (2022-01-06)

**Note:** Version bump only for package @quenty/blend





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.0.2...@quenty/blend@2.1.0) (2022-01-03)


### Bug Fixes

* Blend.Single specification was wrong ([749b6b3](https://github.com/Quenty/NevermoreEngine/commit/749b6b3cff05f4c80b85bf2f82e6c06186e81c2b))


### Features

* Blend now supports a more stable contract for adding children. ([1dc1846](https://github.com/Quenty/NevermoreEngine/commit/1dc18465f22d23bfe9dca9b0c85bdbb733fa6809))





## [2.0.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.0.1...@quenty/blend@2.0.2) (2021-12-30)

**Note:** Version bump only for package @quenty/blend





## [2.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@2.0.0...@quenty/blend@2.0.1) (2021-12-30)

**Note:** Version bump only for package @quenty/blend





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@1.2.0...@quenty/blend@2.0.0) (2021-12-22)

**Note:** Version bump only for package @quenty/blend





# [1.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/blend@1.1.0...@quenty/blend@1.2.0) (2021-12-18)


### Features

* Allow Color3 spring manipulation, and AccelTween usage ([3417923](https://github.com/Quenty/NevermoreEngine/commit/34179230b3b6bf957e1a363588370990735f8513))





# 1.1.0 (2021-12-14)


### Features

* Add initial Blend package, a declarative UI package like Fusion ([764a13f](https://github.com/Quenty/NevermoreEngine/commit/764a13f107560a180462dbf67878530452005979))





# v1.1.0 (Tue Dec 14 2021)

#### 🚀 Enhancement

- style: Fix linting [#234](https://github.com/Quenty/NevermoreEngine/pull/234) ([@Quenty](https://github.com/Quenty))
- feat: Add initial Blend package, a declarative UI package like Fusion [#234](https://github.com/Quenty/NevermoreEngine/pull/234) ([@Quenty](https://github.com/Quenty))

#### Authors: 1

- James Onnen ([@Quenty](https://github.com/Quenty))
