# ColdRoute Changelog

## 0.3 - Third Release

* Allowed all namespacing features to work with Wheels
  * Fixed dot-syntax for controllers in various places [James G]
  * Fixed dot-syntax for controllers in ```renderWith()``` [Chris]
* Support for ```method``` in ```startFormTag()``` [James G]
* Allow ```requestMethod``` to be overridden in ```$findMatchingRoute()``` [James G]

## 0.2 - Second Release

* Improved internals for mapping and matching [Don]
  * Regex powered route matching
  * Shallow resources
  * Regex constraints for segment variables
  * Optional segment support [James H]
  * Full support for ```[format]```
* New ```constraints()``` method and params [Don]
* New ```on``` parameter for ```match()``` method [Don]

## 0.1.1 - Bug Fixes

* Fixed route helpers to allow strings that appear to be false [Don]

## 0.1 - First Release

* Special chained routing syntax for CFWheels [Don]
  * Resembles the nested block syntax for Rails 3
  * Create routes that only match certain HTTP verbs
  * Create scoped and namespaced routes
  * Create singular and plural resources
    * Quickly generate common HTTP resource routes
    * Optionally generate only some of the route actions
    * Fine-grained control over resource naming
  * Strict rules for generating named routes
* Provide helpers for generating route strings [Don]
  * Method names are derived from named routes
  * Methods take route variables as ordered or named arguments
  * Model objects passed in are automatically converted to keys
* Screen to list all routes (similar to ```rake routes```) [Don]