# ColdRoute

## Purpose

To bring Rails 3 route features and syntax to CFWheels, making namespaces and resources easy to use.

## Installation

Just download the latest ```.zip``` file from the __Downloads__ section of the project. Copy this file into the ```/plugins``` directory of your CFWheels project and reload your application.

## Basics

ColdRoute enables scopes, namespaces, and resources in your routes.

* __Scopes__ are routing settings that automatically apply to multiple routes.
* __Namespaces__ are _scope_ shortcuts to force a prepended path to your routes and controller sub-folder for the controller.
* __Resources__ are common manipulation methods for managing creation, update, and removal of a type of entity.

Routes can also be specified by HTTP method (GET, POST, PUT, or DELETE.) If the exact HTTP method is not used, the route will not be matched. This also allows the same exact path to correspond to more than one route.

## How To Use?

After reloading your application, ColdRoute will be available to use in your ```/config/routes.cfm``` file. The route drawing process is triggered by calling ```drawRoutes()```, and then chaining method calls before closing with ```.end();```

### Simple routes

Here is how you would create a route with the pattern ```/login``` that maps to the ```Session#new``` action:

```coldfusion
drawRoutes()
	.match(pattern="/login", controller="session", action="new")
.end();
```

The same can be done by using the shorthand ```to``` syntax:

```coldfusion
drawRoutes()
	.match(pattern="/login", to="session##new")
.end();
```

And the route can be given a name to allow for easier matching:

```coldfusion
drawRoutes()
	.match(name="login", pattern="/login", to="session##new")
.end();
```

We can also define the routes with HTTP method helpers. So the same path can match two different actions, depending on the method used.

```coldfusion
drawRoutes()
        .get(name="login", pattern="/login", to="session##new")
        .post(name="login", pattern="/login", to="session##create")
.end();
```

Produces the routes:

* ```GET /login``` => ```session#new```
* ```POST /login``` => ```session#create```

As with the original CFWheels routing implementation, there are concepts such as the _default route_, route variables, and the wildcard route. Each of these is demonstrated below:

```coldfusion
drawRoutes()
	.get(name="viewPost", pattern="/posts/[key]", to="post##view")
	.wildcard()
	.root(to="home##index")
.end();
```

Note that the call to ```wildcard()``` will produce the following routes:

* ```/[controller]/[action]/[key]```
* ```/[controller]/[action]```
* ```/[controller]```

### Scoping

When a set of routes share common properties, it makes sense to use the ```scope()``` method to set those properties across multiple routes. The following properties can be set: ```controller, path, module```.

```coldfusion
drawRoutes()
	.scope(path="/reports", controller="reports")
		.get("albums")
		.get("artists")
		.get("favoriteTracks")
	.end()
.end();
```

This would produce the following routes:

* ```GET /reports/albums``` => ```reports#albums```
* ```GET /reports/artists``` => ```reports#artists```
* ```GET /reports/favorite-tracks``` => ```reports#favoriteTracks```

Note the special syntax ```get("favoriteTracks")``` is the same as calling ```get(name="favoriteTracks", pattern="favorite-tracks", action="favoriteTracks")```. Also, the ```path``` parameter from ```scope()``` is appended to the ```pattern``` from ```get()```, and the ```controller``` parameter is preserved.

#### Namespaces

Modules (or namespaces) are really just controller sub-folders. If a controller name is ```admin.products.item```, then the module is ```admin.products``` The controller would be initialized using the ```/controllers/admin/products/Item.cfc``` component.

A route for this could be created by calling:

```coldfusion
drawRoutes().
	.namespace("admin")
		.namespace("products")
			.get(pattern="items", to="item##index")
		.end()
	.end()
.end();
```

This produces the single route:

* ```GET /admin/products/items``` => ```admin.products.item#index```

All the ```namespace("admin")``` call really does is call ```scope(path="/admin", module="admin")```. This causes ```admin``` to be prepended to all controller names used within the namespace. While this is questionable for use in an MVC application, it does help to organize complex applications with lots of controllers and views.