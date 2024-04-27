# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [10.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@10.1.0...@quenty/loader@10.2.0) (2024-04-27)

**Note:** Version bump only for package @quenty/loader





# [10.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@10.0.0...@quenty/loader@10.1.0) (2024-03-09)

**Note:** Version bump only for package @quenty/loader





# [10.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@9.0.0...@quenty/loader@10.0.0) (2024-02-14)


### Bug Fixes

* Fix loader tracking going infinite ([cd67bf3](https://github.com/Quenty/NevermoreEngine/commit/cd67bf34d1d5c92f93eb5cc349b9e179cbd8a042))





# [9.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@8.0.0...@quenty/loader@9.0.0) (2024-02-13)


### Bug Fixes

* Fix bootstrap of test environments and loader samples ([441e4a9](https://github.com/Quenty/NevermoreEngine/commit/441e4a90d19fcc203da2fdedc08e532c20d52f99))





# [8.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@7.3.0...@quenty/loader@8.0.0) (2024-02-13)


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





# [7.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@7.1.0...@quenty/loader@7.3.0) (2024-01-08)


### Features

* Add Queue:GetCount() ([2e6ee3c](https://github.com/Quenty/NevermoreEngine/commit/2e6ee3cf54df42aebc84b192f2156afddedfd75d))


### Performance Improvements

* Cache loader require values ([bab28c9](https://github.com/Quenty/NevermoreEngine/commit/bab28c969a91d0eb57086eb860be648ac36378e3))





# [7.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@7.0.0...@quenty/loader@7.1.0) (2023-12-14)


### Features

* Reduce duplicate __call() and __index code ([422d019](https://github.com/Quenty/NevermoreEngine/commit/422d0193378076fca308c96a330ad6da0eb3784e))
* Return server, client, and shared folders so they can be renamed ([8a12f42](https://github.com/Quenty/NevermoreEngine/commit/8a12f4225b91767b8ec87f3a1569a47c1a5154ce))





# [7.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.3.0...@quenty/loader@7.0.0) (2023-10-11)

**Note:** Version bump only for package @quenty/loader





# [6.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.2.1...@quenty/loader@6.3.0) (2023-08-23)


### Features

* Add Maid:Add() which returns the task you pass into the maid ([bf9e3d6](https://github.com/Quenty/NevermoreEngine/commit/bf9e3d66e5c31ec0dafcc1c9e4142d963d309c65))





## [6.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.2.0...@quenty/loader@6.2.1) (2023-04-07)


### Bug Fixes

* Loader provides better error message ([777f5eb](https://github.com/Quenty/NevermoreEngine/commit/777f5eb7764f6dad39f9ed7e0d11d717ac609d56))





# [6.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.1.0...@quenty/loader@6.2.0) (2023-03-05)


### Bug Fixes

* Maids would sometimes error while cancelling threads they were part of. This ensures full cancellation. ([252fc3a](https://github.com/Quenty/NevermoreEngine/commit/252fc3a5b097dc1a58a998a261b2c28d367839d4))





# [6.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.0.1...@quenty/loader@6.1.0) (2023-02-21)

**Note:** Version bump only for package @quenty/loader





## [6.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@6.0.0...@quenty/loader@6.0.1) (2022-11-04)


### Bug Fixes

* Fix hoarcekat stories not loading correctly when installed in a flat version of the repository (for example, via normal npm install @quenty/blend) ([02772ca](https://github.com/Quenty/NevermoreEngine/commit/02772caf01fd5c055edf64c7f26b2c06b379e9e3))





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@5.0.1...@quenty/loader@6.0.0) (2022-09-27)


### Bug Fixes

* Add untested hot reloading loader replication logic ([384a8f1](https://github.com/Quenty/NevermoreEngine/commit/384a8f166c781a6d67485d8cee1269915ba2a5ad))


### Features

* Support hiding server code behind the camera ([afc0e0a](https://github.com/Quenty/NevermoreEngine/commit/afc0e0a35592f68397d6db8108e7955b737ecfe0))





## [5.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@5.0.0...@quenty/loader@5.0.1) (2022-08-16)

**Note:** Version bump only for package @quenty/loader





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@4.1.0...@quenty/loader@5.0.0) (2022-05-21)


### Bug Fixes

* Handle objectvalues linked in the actual package folder (as top-level packages) ([b678f55](https://github.com/Quenty/NevermoreEngine/commit/b678f55989c30d9bab53724ca0573b8fea125aaf))





# [4.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@4.0.0...@quenty/loader@4.1.0) (2022-03-27)

**Note:** Version bump only for package @quenty/loader





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.4.0...@quenty/loader@4.0.0) (2022-03-06)


### Bug Fixes

* Duplicate module info actually errors properly ([d3d451f](https://github.com/Quenty/NevermoreEngine/commit/d3d451f24ecc3f6debeb802bd4de6b7276369403))





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.3.0...@quenty/loader@3.4.0) (2022-01-17)


### Features

* Allow plugins to be bootstrapped allowing access to both client and server code within the plugin. ([6147051](https://github.com/Quenty/NevermoreEngine/commit/61470516702b7daa0ec020630556e7505e09aac1))





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.2.0...@quenty/loader@3.3.0) (2022-01-07)


### Bug Fixes

* Centralize loader constants ([2bfd287](https://github.com/Quenty/NevermoreEngine/commit/2bfd287a369a6cbcd307a0983f47d246f1bf32a4))





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.1.2...@quenty/loader@3.2.0) (2022-01-03)


### Bug Fixes

* Better error messages ([821f1ce](https://github.com/Quenty/NevermoreEngine/commit/821f1cefc9297c26c5aab2e414618de183857d21))





## [3.1.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.1.1...@quenty/loader@3.1.2) (2021-12-30)

**Note:** Version bump only for package @quenty/loader





## [3.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.1.0...@quenty/loader@3.1.1) (2021-10-30)


### Bug Fixes

* Allow NexusUnitTest to load packages for unit testing ([4ea04fa](https://github.com/Quenty/NevermoreEngine/commit/4ea04fa50d3908f71bd6f14a14ef4a74be6cdb00))





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.0.1...@quenty/loader@3.1.0) (2021-10-02)


### Features

* Loader performance optimizations ([5a99a48](https://github.com/Quenty/NevermoreEngine/commit/5a99a4885685fce43c4214c088be459c5a18b4b5))





## [3.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@3.0.0...@quenty/loader@3.0.1) (2021-09-18)


### Bug Fixes

* Better warnings in loader and also allow multiple groups ([7215ba4](https://github.com/Quenty/NevermoreEngine/commit/7215ba425e85bf5ad080d72f39d7645fa8e4fe06))
* Handle deferred mode and loader in test mode in loader ([514cd90](https://github.com/Quenty/NevermoreEngine/commit/514cd9043d20b6d2f2c019e920b19212b0dc96af))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@2.1.0...@quenty/loader@3.0.0) (2021-09-11)


### Bug Fixes

* Misc loading issues fixed, including loading injection and other issues ([8fc255b](https://github.com/Quenty/NevermoreEngine/commit/8fc255ba912c343f6c615f37c4e465abda0edac8))





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@2.0.0...@quenty/loader@2.1.0) (2021-09-05)


### Bug Fixes

* Discover top level module scripts ([23fc167](https://github.com/Quenty/NevermoreEngine/commit/23fc1676f1140bb75e818e8aae0fb5fd514a5065))
* Ensure loader injects itself ([b5d9a83](https://github.com/Quenty/NevermoreEngine/commit/b5d9a838d0c8cb4df83bf606eb56c69b64c75002))
* Loader allows container ([988eefd](https://github.com/Quenty/NevermoreEngine/commit/988eefdfa26f4b547da829cf7ddf65a58747b7c8))





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/loader@1.2.0...@quenty/loader@2.0.0) (2021-09-05)


### Bug Fixes

* Remove peer dependencies. This is because lerna doesn't really support peer dependencies being linked and getting a new version on build, which is unfortunate. ([5f5aeee](https://github.com/Quenty/NevermoreEngine/commit/5f5aeeea8de9975435309e53679f0ef7064f9dd0))





# 1.2.0 (2021-07-31)


### Bug Fixes

* Add CI and CD ([47513e9](https://github.com/Quenty/NevermoreEngine/commit/47513e9b568162707534af132396dd8756947dd3))
* Adjust CI badge to show automatic build and release state ([5a55d3f](https://github.com/Quenty/NevermoreEngine/commit/5a55d3f19bf8d66a760d67da9b56ed47fab74656))
* Fix selene linting ([45fc074](https://github.com/Quenty/NevermoreEngine/commit/45fc07489ee59127ac6582689f19a0e87c1e5b5a))



## 1.0.2 (2021-07-25)



## 1.0.1 (2021-07-25)



# 1.0.0 (2021-07-24)
