# ColdRoute Changelog

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