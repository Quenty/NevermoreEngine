# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

# [7.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@7.2.1...@quenty/datastore@7.3.0) (2022-11-08)

**Note:** Version bump only for package @quenty/datastore





## [7.2.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@7.2.0...@quenty/datastore@7.2.1) (2022-11-04)

**Note:** Version bump only for package @quenty/datastore





# [7.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@7.1.0...@quenty/datastore@7.2.0) (2022-10-28)


### Bug Fixes

* Import maid ([638e529](https://github.com/Quenty/NevermoreEngine/commit/638e529d87b3ae4df73482e91153540f41baaf36))


### Features

* Free DataStore key after its writer GCs to allow future writers ([9b2e8a2](https://github.com/Quenty/NevermoreEngine/commit/9b2e8a29332aacb99ac47550af37708f58cd39e5))





# [7.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@7.0.0...@quenty/datastore@7.1.0) (2022-10-11)


### Bug Fixes

* Remove init.meta.json since it breaks in team create ([cba21e6](https://github.com/Quenty/NevermoreEngine/commit/cba21e602b50ea3799044eae9cb690d1cd9c88ec))





# [7.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@6.1.0...@quenty/datastore@7.0.0) (2022-09-27)


### Bug Fixes

* Hide server code by default from replication using cameras and init.meta.json. ([5636dd8](https://github.com/Quenty/NevermoreEngine/commit/5636dd8cafe68db4571ed214a82b84698f2f74c0))


### Features

* Add BindToCloseService package and implement across places binding to close ([afdd829](https://github.com/Quenty/NevermoreEngine/commit/afdd829538c9d0ce2d6f51ad9fee9063f0f5bd24))





# [6.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@6.0.1...@quenty/datastore@6.1.0) (2022-08-22)

**Note:** Version bump only for package @quenty/datastore





## [6.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@6.0.0...@quenty/datastore@6.0.1) (2022-08-16)

**Note:** Version bump only for package @quenty/datastore





# [6.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@5.3.0...@quenty/datastore@6.0.0) (2022-08-14)


### Features

* Add ServiceName to most services for faster debugging ([39fc3f4](https://github.com/Quenty/NevermoreEngine/commit/39fc3f4f2beb92fff49b2264424e07af7907324e))





# [5.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@5.2.0...@quenty/datastore@5.3.0) (2022-07-31)


### Bug Fixes

* Add DataStore SetCacheTime (not implemented yet) ([906e723](https://github.com/Quenty/NevermoreEngine/commit/906e72397075200e8cb8b98bc8b7b7f96d992907))


### Features

* Add GameDataStoreService service for global game data ([5f6d52c](https://github.com/Quenty/NevermoreEngine/commit/5f6d52ca9f2be811c426714cd6d94d9794f366b5))
* Support StoreOnValueChange with non ValueBase instances. ([ab45498](https://github.com/Quenty/NevermoreEngine/commit/ab4549833f41f2b3d8b43202965fd3202b649770))





# [5.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@5.1.0...@quenty/datastore@5.2.0) (2022-07-02)


### Bug Fixes

* Can clean up services properly ([eb45e03](https://github.com/Quenty/NevermoreEngine/commit/eb45e03ce2897b18f1ae460974bf2bbb9e27cb97))


### Features

* Add DataStorePromises support for ordered data stores ([927bdd9](https://github.com/Quenty/NevermoreEngine/commit/927bdd94b68eef114cff5a1eb6dc03d6db5867d8))





# [5.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@5.0.0...@quenty/datastore@5.1.0) (2022-06-21)


### Bug Fixes

* Add better warnings for when store is already destroyed while writing or storing ([77544eb](https://github.com/Quenty/NevermoreEngine/commit/77544ebf9620c1f34b62d92eb45e9c95c819186f))





# [5.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@4.3.0...@quenty/datastore@5.0.0) (2022-05-21)

**Note:** Version bump only for package @quenty/datastore





# [4.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@4.2.0...@quenty/datastore@4.3.0) (2022-03-27)

**Note:** Version bump only for package @quenty/datastore





# [4.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@4.1.0...@quenty/datastore@4.2.0) (2022-03-20)

**Note:** Version bump only for package @quenty/datastore





# [4.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@4.0.0...@quenty/datastore@4.1.0) (2022-03-10)

**Note:** Version bump only for package @quenty/datastore





# [4.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.6.0...@quenty/datastore@4.0.0) (2022-03-06)


### Features

* Can add removing promises to datastore before save ([653bef8](https://github.com/Quenty/NevermoreEngine/commit/653bef8717e4470cf94340e67ff69eab1b7269f6))





# [3.6.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.5.1...@quenty/datastore@3.6.0) (2022-01-17)


### Features

* Add optional PlayerDataStoreService to centralize datastore usage across submodules. ([1c4349f](https://github.com/Quenty/NevermoreEngine/commit/1c4349fa3ed4ef59ed41117319057ca9e2bd6dfd))





## [3.5.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.5.0...@quenty/datastore@3.5.1) (2022-01-16)

**Note:** Version bump only for package @quenty/datastore





# [3.5.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.4.0...@quenty/datastore@3.5.0) (2022-01-07)

**Note:** Version bump only for package @quenty/datastore





# [3.4.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.3.2...@quenty/datastore@3.4.0) (2022-01-03)

**Note:** Version bump only for package @quenty/datastore





## [3.3.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.3.1...@quenty/datastore@3.3.2) (2021-12-30)

**Note:** Version bump only for package @quenty/datastore





## [3.3.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.3.0...@quenty/datastore@3.3.1) (2021-12-30)

**Note:** Version bump only for package @quenty/datastore





# [3.3.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.2.0...@quenty/datastore@3.3.0) (2021-12-18)

**Note:** Version bump only for package @quenty/datastore





# [3.2.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.1.2...@quenty/datastore@3.2.0) (2021-11-20)


### Bug Fixes

* Support MacOS syncing ([#225](https://github.com/Quenty/NevermoreEngine/issues/225)) ([03f9183](https://github.com/Quenty/NevermoreEngine/commit/03f918392c6a5bdd33f8a17c38de371d1e06c67a))





## [3.1.2](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.1.1...@quenty/datastore@3.1.2) (2021-10-30)

**Note:** Version bump only for package @quenty/datastore





## [3.1.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.1.0...@quenty/datastore@3.1.1) (2021-10-06)

**Note:** Version bump only for package @quenty/datastore





# [3.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.0.1...@quenty/datastore@3.1.0) (2021-10-02)

**Note:** Version bump only for package @quenty/datastore





## [3.0.1](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@3.0.0...@quenty/datastore@3.0.1) (2021-09-18)


### Bug Fixes

* Fix undeclare package dependencies that prevented loading in certain situations ([a8be7e0](https://github.com/Quenty/NevermoreEngine/commit/a8be7e06a06506a71257862429934e2ed0f6f56b))





# [3.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@2.1.0...@quenty/datastore@3.0.0) (2021-09-11)

**Note:** Version bump only for package @quenty/datastore





# [2.1.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@2.0.0...@quenty/datastore@2.1.0) (2021-09-05)

**Note:** Version bump only for package @quenty/datastore





# [2.0.0](https://github.com/Quenty/NevermoreEngine/compare/@quenty/datastore@1.2.0...@quenty/datastore@2.0.0) (2021-09-05)


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
