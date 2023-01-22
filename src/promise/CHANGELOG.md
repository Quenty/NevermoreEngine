# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [6.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@6.0.0...@quenty/promise@6.0.1) (2022-11-04)

**Note:** Version bump only for package @quenty/promise





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@5.1.1...@quenty/promise@6.0.0) (2022-09-27)


### Bug Fixes

* Fix function returning call scenario ([7a099f3](https://github.com/Quenty/NevermoreEngine/commit/7a099f320918a6a520ed9e35c5e777cf895a05f6))





## [5.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@5.1.0...@quenty/promise@5.1.1) (2022-08-16)

**Note:** Version bump only for package @quenty/promise





# [5.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@5.0.0...@quenty/promise@5.1.0) (2022-07-31)


### Bug Fixes

* Promise uses task.defer() instead of Heartbeat ([0ae1e7a](https://github.com/Quenty/NevermoreEngine/commit/0ae1e7aa92543bf220ebd594772dea9b6b586612))
* Replace coroutine.resume in favor of task.spawn ([#260](https://github.com/Quenty/NevermoreEngine/issues/260)) ([3686a1e](https://github.com/Quenty/NevermoreEngine/commit/3686a1e7926c0c5d116bd51843a95a5bb4e33743))





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@4.2.0...@quenty/promise@5.0.0) (2022-05-21)

**Note:** Version bump only for package @quenty/promise





# [4.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@4.1.0...@quenty/promise@4.2.0) (2022-03-27)

**Note:** Version bump only for package @quenty/promise





# [4.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@4.0.0...@quenty/promise@4.1.0) (2022-03-10)

**Note:** Version bump only for package @quenty/promise





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.6.0...@quenty/promise@4.0.0) (2022-03-06)


### Performance Improvements

* Return the promise transparently is we only have one promise ([f717878](https://github.com/Quenty/NevermoreEngine/commit/f7178782904ed8fc425365bb0c41f3ffd63ab013))





# [3.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.5.1...@quenty/promise@3.6.0) (2022-01-17)

**Note:** Version bump only for package @quenty/promise





## [3.5.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.5.0...@quenty/promise@3.5.1) (2022-01-16)

**Note:** Version bump only for package @quenty/promise





# [3.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.4.0...@quenty/promise@3.5.0) (2022-01-07)

**Note:** Version bump only for package @quenty/promise





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.3.1...@quenty/promise@3.4.0) (2022-01-03)

**Note:** Version bump only for package @quenty/promise





## [3.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.3.0...@quenty/promise@3.3.1) (2021-12-30)

**Note:** Version bump only for package @quenty/promise





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.2.0...@quenty/promise@3.3.0) (2021-12-18)


### Bug Fixes

* Use Promies.spawn() since task.spawn() is probably cheaper now ([6a069c2](https://github.com/Quenty/NevermoreEngine/commit/6a069c2a1c99ca34f53af747a969d5f5c4044e84))





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.1.2...@quenty/promise@3.2.0) (2021-11-20)


### Bug Fixes

* Support MacOS syncing ([#225](https://github.com/Quenty/NevermoreEngine/issues/225)) ([03f9183](https://github.com/Quenty/NevermoreEngine/commit/03f918392c6a5bdd33f8a17c38de371d1e06c67a))





## [3.1.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.1.1...@quenty/promise@3.1.2) (2021-10-30)

**Note:** Version bump only for package @quenty/promise





## [3.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.1.0...@quenty/promise@3.1.1) (2021-10-06)

**Note:** Version bump only for package @quenty/promise





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.0.1...@quenty/promise@3.1.0) (2021-10-02)

**Note:** Version bump only for package @quenty/promise





## [3.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@3.0.0...@quenty/promise@3.0.1) (2021-09-18)

**Note:** Version bump only for package @quenty/promise





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@2.1.0...@quenty/promise@3.0.0) (2021-09-11)

**Note:** Version bump only for package @quenty/promise





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@2.0.0...@quenty/promise@2.1.0) (2021-09-05)

**Note:** Version bump only for package @quenty/promise





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/promise@1.2.0...@quenty/promise@2.0.0) (2021-09-05)


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
