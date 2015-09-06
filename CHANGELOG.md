# Change Log

## Master
### Fixed
* Fix ZeroDivisionError bug in `--threads` option [#24]

### Removed
* Removed Gemfile.lock as it is customary for gems [#23]

## 0.2.1
### Added
* Update contentful-management.rb dependency to 0.7.1 [#21]

### Fixed
* Allows installed binstub to actually be used [#22]

## 0.2.0
### Added
* Import validations for content types
* Update contentful-management.rb dependency to 0.7.0 [#18]
* Revised cli interface [#17]

## 0.1.1
### Added
* Log asset errors similar to entry import errors

## 0.1.0
### Added
* Log publish errors similar to import errors

### Fixed
* Introduce proper namespacing of all classes

## 0.0.2
### Added
* Read contentType and description from asset JSON files, falling back to contentType inference from the asset URL.

## 0.0.1
### Other
* Initial release
