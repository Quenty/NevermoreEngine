# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [14.5.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.5.0...@quenty/camera@14.5.1) (2024-07-16)


### Bug Fixes

* CameraControls destruction in Enabled state ([#477](https://github.com/Quenty/NevermoreEngine/issues/477)) ([ef6975e](https://github.com/Quenty/NevermoreEngine/commit/ef6975e7fb2d396569f33231d45b32684e803940))





# [14.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.4.0...@quenty/camera@14.5.0) (2024-05-09)


### Bug Fixes

* Bootstrap specifically to loader ([7f4d4f9](https://github.com/Quenty/NevermoreEngine/commit/7f4d4f9cd4a6602af8daaf04983bb349dafc7e95))
* Fix .package-lock.json replicating in packages ([75d0efe](https://github.com/Quenty/NevermoreEngine/commit/75d0efeef239f221d93352af71a5b3e930ec23c5))
* Fix camera stack return in CameraStackService ([a3b8c67](https://github.com/Quenty/NevermoreEngine/commit/a3b8c6779420143d2aa2ccc979259bb23a130703))


### Features

* Adjust camera state tweener to support camera stack ([677b621](https://github.com/Quenty/NevermoreEngine/commit/677b6210bcfe2adfb85a1cadf1006a4642be1ba3))





# [14.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.3.0...@quenty/camera@14.4.0) (2024-05-03)

**Note:** Version bump only for package @quenty/camera





# [14.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.2.1...@quenty/camera@14.3.0) (2024-04-27)

**Note:** Version bump only for package @quenty/camera





## [14.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.2.0...@quenty/camera@14.2.1) (2024-04-23)

**Note:** Version bump only for package @quenty/camera





# [14.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.1.0...@quenty/camera@14.2.0) (2024-03-27)

**Note:** Version bump only for package @quenty/camera





# [14.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@14.0.0...@quenty/camera@14.1.0) (2024-03-09)


### Features

* Expose RenderPriority in CameraStackService ([4d44a82](https://github.com/Quenty/NevermoreEngine/commit/4d44a82857060c7e7ef4a5598a56bec8e7c03a88))





# [14.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@13.0.0...@quenty/camera@14.0.0) (2024-02-14)

**Note:** Version bump only for package @quenty/camera





# [13.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@12.0.0...@quenty/camera@13.0.0) (2024-02-13)


### Bug Fixes

* Fix bootstrap of test environments and loader samples ([441e4a9](https://github.com/Quenty/NevermoreEngine/commit/441e4a90d19fcc203da2fdedc08e532c20d52f99))





# [12.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@11.0.0...@quenty/camera@12.0.0) (2024-02-13)


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





# [11.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@10.2.0...@quenty/camera@11.0.0) (2024-01-10)

**Note:** Version bump only for package @quenty/camera





# [10.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@10.1.0...@quenty/camera@10.2.0) (2024-01-08)

**Note:** Version bump only for package @quenty/camera





# [10.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@10.0.0...@quenty/camera@10.1.0) (2023-12-14)

**Note:** Version bump only for package @quenty/camera





# [10.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.21.0...@quenty/camera@10.0.0) (2023-10-11)

**Note:** Version bump only for package @quenty/camera





# [9.21.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.20.0...@quenty/camera@9.21.0) (2023-08-23)


### Bug Fixes

* Add warning if no predicate is set in OverrideDefaultCameraToo ([021fc7c](https://github.com/Quenty/NevermoreEngine/commit/021fc7c7a5f330702268feb829ef9302499e7afb))





# [9.20.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.19.0...@quenty/camera@9.20.0) (2023-07-28)

**Note:** Version bump only for package @quenty/camera





# [9.19.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.18.0...@quenty/camera@9.19.0) (2023-07-28)


### Features

* Allow for layered camera impulse ([#399](https://github.com/Quenty/NevermoreEngine/issues/399)) ([458add5](https://github.com/Quenty/NevermoreEngine/commit/458add5c045cd120ec7f81a902fc9dfe5ed6da4b))





# [9.18.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.17.0...@quenty/camera@9.18.0) (2023-07-15)

**Note:** Version bump only for package @quenty/camera





# [9.17.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.16.0...@quenty/camera@9.17.0) (2023-06-24)


### Bug Fixes

* Assert speed set on CameraStateTweener is a number ([0cef9b5](https://github.com/Quenty/NevermoreEngine/commit/0cef9b552f3d3c795e9a6f854de1009af8b7f1fb))





# [9.16.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.15.0...@quenty/camera@9.16.0) (2023-06-18)


### Features

* Better interopability between Roblox and camera stack system ([1916352](https://github.com/Quenty/NevermoreEngine/commit/1916352394a777ec6ab01e869cc7d0cfe92bae76))





# [9.15.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.14.0...@quenty/camera@9.15.0) (2023-06-17)

**Note:** Version bump only for package @quenty/camera





# [9.14.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.13.0...@quenty/camera@9.14.0) (2023-06-05)


### Bug Fixes

* Better Camea warnings on NaN values ([9c76820](https://github.com/Quenty/NevermoreEngine/commit/9c7682087d946c235a46ea1377c20a2e1b5994f2))





# [9.13.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.12.0...@quenty/camera@9.13.0) (2023-05-26)


### Features

* Initial refactor of guis to use ValueObject instead of ValueObject ([723aba0](https://github.com/Quenty/NevermoreEngine/commit/723aba0208cae7e06c9d8bf2d8f0092d042d70ea))





# [9.12.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.11.0...@quenty/camera@9.12.0) (2023-05-08)

**Note:** Version bump only for package @quenty/camera





# [9.11.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.10.1...@quenty/camera@9.11.0) (2023-04-10)

**Note:** Version bump only for package @quenty/camera





## [9.10.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.10.0...@quenty/camera@9.10.1) (2023-04-07)

**Note:** Version bump only for package @quenty/camera





# [9.10.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.9.0...@quenty/camera@9.10.0) (2023-03-31)

**Note:** Version bump only for package @quenty/camera





# [9.9.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.8.0...@quenty/camera@9.9.0) (2023-03-05)

**Note:** Version bump only for package @quenty/camera





# [9.8.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.7.0...@quenty/camera@9.8.0) (2023-02-27)

**Note:** Version bump only for package @quenty/camera





# [9.7.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.6.0...@quenty/camera@9.7.0) (2023-02-21)

**Note:** Version bump only for package @quenty/camera





# [9.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.5.0...@quenty/camera@9.6.0) (2022-12-06)


### Features

* Add :SetAcceleration(acceleration) on GamepadRotateModel to allow for a more linear control of the camera ([3aec535](https://github.com/Quenty/NevermoreEngine/commit/3aec535dc88ed97ff4762e4b50d6e46d4c6c6ecb))





# [9.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.4.0...@quenty/camera@9.5.0) (2022-11-19)

**Note:** Version bump only for package @quenty/camera





# [9.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.3.1...@quenty/camera@9.4.0) (2022-11-12)

**Note:** Version bump only for package @quenty/camera





## [9.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.3.0...@quenty/camera@9.3.1) (2022-11-04)

**Note:** Version bump only for package @quenty/camera





# [9.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.2.0...@quenty/camera@9.3.0) (2022-10-30)

**Note:** Version bump only for package @quenty/camera





# [9.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.1.1...@quenty/camera@9.2.0) (2022-10-23)


### Features

* Move CameraStack to its own reusable class ([7020502](https://github.com/Quenty/NevermoreEngine/commit/70205024acb508552c0c922a0a8119a27b7f38cd))





## [9.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.1.0...@quenty/camera@9.1.1) (2022-10-16)


### Bug Fixes

* CameraStack ends profile correctly if disabled ([cdca1bd](https://github.com/Quenty/NevermoreEngine/commit/cdca1bdb4dfcc7da576687114d2343568db131ab))





# [9.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@9.0.0...@quenty/camera@9.1.0) (2022-10-11)

**Note:** Version bump only for package @quenty/camera





# [9.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@8.1.0...@quenty/camera@9.0.0) (2022-09-27)

**Note:** Version bump only for package @quenty/camera





# [8.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@8.0.1...@quenty/camera@8.1.0) (2022-08-22)

**Note:** Version bump only for package @quenty/camera





## [8.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@8.0.0...@quenty/camera@8.0.1) (2022-08-16)

**Note:** Version bump only for package @quenty/camera





# [8.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@7.3.0...@quenty/camera@8.0.0) (2022-08-14)


### Features

* Add ServiceName to most services for faster debugging ([39fc3f4](https://github.com/Quenty/NevermoreEngine/commit/39fc3f4f2beb92fff49b2264424e07af7907324e))





# [7.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@7.2.0...@quenty/camera@7.3.0) (2022-07-31)

**Note:** Version bump only for package @quenty/camera





# [7.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@7.1.0...@quenty/camera@7.2.0) (2022-07-02)


### Bug Fixes

* Can clean up services properly ([eb45e03](https://github.com/Quenty/NevermoreEngine/commit/eb45e03ce2897b18f1ae460974bf2bbb9e27cb97))





# [7.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@7.0.0...@quenty/camera@7.1.0) (2022-06-21)


### Bug Fixes

* Delay CameraStackService starting until start method so that configuration has time to be set ([02d68d1](https://github.com/Quenty/NevermoreEngine/commit/02d68d1d8fbba5b9685c29c503520796c55fa3fa))





# [7.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@6.3.0...@quenty/camera@7.0.0) (2022-05-21)

**Note:** Version bump only for package @quenty/camera





# [6.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@6.2.0...@quenty/camera@6.3.0) (2022-03-27)

**Note:** Version bump only for package @quenty/camera





# [6.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@6.1.0...@quenty/camera@6.2.0) (2022-03-20)

**Note:** Version bump only for package @quenty/camera





# [6.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@6.0.0...@quenty/camera@6.1.0) (2022-03-10)

**Note:** Version bump only for package @quenty/camera





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.3.0...@quenty/camera@6.0.0) (2022-03-06)

**Note:** Version bump only for package @quenty/camera





# [5.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.2.1...@quenty/camera@5.3.0) (2022-01-17)

**Note:** Version bump only for package @quenty/camera





## [5.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.2.0...@quenty/camera@5.2.1) (2022-01-16)

**Note:** Version bump only for package @quenty/camera





# [5.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.1.1...@quenty/camera@5.2.0) (2022-01-07)

**Note:** Version bump only for package @quenty/camera





## [5.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.1.0...@quenty/camera@5.1.1) (2022-01-06)

**Note:** Version bump only for package @quenty/camera





# [5.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.0.2...@quenty/camera@5.1.0) (2022-01-03)

**Note:** Version bump only for package @quenty/camera





## [5.0.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.0.1...@quenty/camera@5.0.2) (2021-12-30)

**Note:** Version bump only for package @quenty/camera





## [5.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@5.0.0...@quenty/camera@5.0.1) (2021-12-30)

**Note:** Version bump only for package @quenty/camera





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.4.0...@quenty/camera@5.0.0) (2021-12-22)

**Note:** Version bump only for package @quenty/camera





# [4.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.3.1...@quenty/camera@4.4.0) (2021-12-18)


### Features

* Better camera explainability ([4fd9016](https://github.com/Quenty/NevermoreEngine/commit/4fd9016f6914bf181e421753cbaca555394537d8))





## [4.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.3.0...@quenty/camera@4.3.1) (2021-12-04)

**Note:** Version bump only for package @quenty/camera





# [4.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.2.4...@quenty/camera@4.3.0) (2021-11-20)


### Bug Fixes

* Support MacOS syncing ([#225](https://github.com/Quenty/NevermoreEngine/issues/225)) ([03f9183](https://github.com/Quenty/NevermoreEngine/commit/03f918392c6a5bdd33f8a17c38de371d1e06c67a))





## [4.2.4](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.2.3...@quenty/camera@4.2.4) (2021-11-10)

**Note:** Version bump only for package @quenty/camera





## [4.2.3](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.2.2...@quenty/camera@4.2.3) (2021-10-30)

**Note:** Version bump only for package @quenty/camera





## [4.2.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.2.1...@quenty/camera@4.2.2) (2021-10-13)

**Note:** Version bump only for package @quenty/camera





## [4.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.2.0...@quenty/camera@4.2.1) (2021-10-06)

**Note:** Version bump only for package @quenty/camera





# [4.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.1.0...@quenty/camera@4.2.0) (2021-10-02)

**Note:** Version bump only for package @quenty/camera





# [4.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.0.1...@quenty/camera@4.1.0) (2021-09-22)


### Bug Fixes

* Add test to CameraUtils ([345c39b](https://github.com/Quenty/NevermoreEngine/commit/345c39b8983ad02f21b3e2c791697de4019f85f2))





## [4.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@4.0.0...@quenty/camera@4.0.1) (2021-09-18)


### Bug Fixes

* Allow stories to be loaded into the actual package in question ([941348a](https://github.com/Quenty/NevermoreEngine/commit/941348a6e59742adf4f3824403814679964ad87e))
* Fix undeclare package dependencies that prevented loading in certain situations ([a8be7e0](https://github.com/Quenty/NevermoreEngine/commit/a8be7e06a06506a71257862429934e2ed0f6f56b))





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@3.1.0...@quenty/camera@4.0.0) (2021-09-11)

**Note:** Version bump only for package @quenty/camera





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@3.0.0...@quenty/camera@3.1.0) (2021-09-05)

**Note:** Version bump only for package @quenty/camera





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@2.0.1...@quenty/camera@3.0.0) (2021-09-05)


### Bug Fixes

* Remove peer dependencies. This is because lerna doesn't really support peer dependencies being linked and getting a new version on build, which is unfortunate. ([5f5aeee](https://github.com/Quenty/NevermoreEngine/commit/5f5aeeea8de9975435309e53679f0ef7064f9dd0))





## [2.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@2.0.0...@quenty/camera@2.0.1) (2021-08-06)


### Bug Fixes

* Fix version numbers locked to canary versions ([ce57664](https://github.com/Quenty/NevermoreEngine/commit/ce57664e1a084db7837d673526f3072ea7556f10))





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/camera@1.2.0...@quenty/camera@2.0.0) (2021-08-06)

**Note:** Version bump only for package @quenty/camera





# 1.2.0 (2021-07-31)


### Bug Fixes

* Add CI and CD ([47513e9](https://github.com/Quenty/NevermoreEngine/commit/47513e9b568162707534af132396dd8756947dd3))
* Adjust CI badge to show automatic build and release state ([5a55d3f](https://github.com/Quenty/NevermoreEngine/commit/5a55d3f19bf8d66a760d67da9b56ed47fab74656))
* Fix CameraFrame.story ([e3b8c1a](https://github.com/Quenty/NevermoreEngine/commit/e3b8c1a3e366e64f38f59b51c5dfbd2cdc401a91))
* Fix selene linting ([45fc074](https://github.com/Quenty/NevermoreEngine/commit/45fc07489ee59127ac6582689f19a0e87c1e5b5a))



## 1.0.2 (2021-07-25)



## 1.0.1 (2021-07-25)



# 1.0.0 (2021-07-24)
