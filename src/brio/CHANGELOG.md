# v3.2.0 (Sat Oct 30 2021)

#### 🚀 Enhancement

- feat: Add unit tests and other small features [#221](https://github.com/Quenty/NevermoreEngine/pull/221) ([@Quenty](https://github.com/Quenty))
- feat: Update RxBrioUtils to allow the transformation of a brio into an observable that emits the value, and then nil, on death. This is like combineLatest. ([@Quenty](https://github.com/Quenty))
- feat: BrioUtils.first allows no brios to be passed into the brio. This allows BrioUtils.flatten to accept non-brios as a result. ([@Quenty](https://github.com/Quenty))

#### 🐛 Bug Fix

- docs: Update BrioDocs ([@Quenty](https://github.com/Quenty))

#### Authors: 1

- James Onnen ([@Quenty](https://github.com/Quenty))

---

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [3.1.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@3.1.1...@quenty/brio@3.1.2) (2021-10-30)

**Note:** Version bump only for package @quenty/brio





## [3.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@3.1.0...@quenty/brio@3.1.1) (2021-10-06)

**Note:** Version bump only for package @quenty/brio





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@3.0.1...@quenty/brio@3.1.0) (2021-10-02)

**Note:** Version bump only for package @quenty/brio





## [3.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@3.0.0...@quenty/brio@3.0.1) (2021-09-18)


### Bug Fixes

* Fix undeclare package dependencies that prevented loading in certain situations ([a8be7e0](https://github.com/Quenty/NevermoreEngine/commit/a8be7e06a06506a71257862429934e2ed0f6f56b))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@2.1.0...@quenty/brio@3.0.0) (2021-09-11)


### Bug Fixes

* Brio passing arguments is safe ([f4e29b0](https://github.com/Quenty/NevermoreEngine/commit/f4e29b020c21aaacabeb841f840753319ad36e77))





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@2.0.0...@quenty/brio@2.1.0) (2021-09-05)

**Note:** Version bump only for package @quenty/brio





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/brio@1.2.0...@quenty/brio@2.0.0) (2021-09-05)


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
