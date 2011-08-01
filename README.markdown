# ColdRoute

## Purpose

To bring Rails 3 route features and syntax to CFWheels, making namespaces and resources easy to use.

## Installation

Just download the latest ```.zip``` file from the __Downloads__ section of the project. Copy this file into the ```/plugins``` directory of your CFWheels project and reload your application.

Optionally, include jQuery 1.4.4+ and the jQuery UJS scripts to get ```data-method```, ```data-confirm```, and  ```data-remote``` links working in your application: https://github.com/rails/jquery-ujs

You can also turn off CFWheels default wildcard routes by placing ```set(loadDefaultRoutes=false)``` in your ```settings.cfm``` file.

__Note:__ I have just posted the latest ```.zip``` file for the plugin. I am making no guarantees on the stability of the code. Also, none of the ```namespace()``` features will work until I submit a patch to CFWheels to enabled complex controller paths.

## Basics

ColdRoute enables HTTP verbs, scopes, namespaces, and resources in your routes.

* __HTTP Verbs__ are the method of each request sent over HTTP (i.e. GET, POST, PUT, and DELETE). They can be used to restrict route matches.
* __Scopes__ are routing settings that automatically apply to multiple routes.
* __Namespaces__ are _scopes_ that force a prepended path to your routes and look for controllers in sub-folders
* __Resources__ are common routes for managing creation, update, and removal of an entity. They use paths combined with HTTP verbs to match routes.

Routes that are specified with HTTP verbs allow the a path to correspond to more than one route, depending on the verb used in the request.

## Building Routes

After reloading your application, ColdRoute will be available to use in your ```/config/routes.cfm``` file. The route drawing process is triggered by calling ```drawRoutes()```, chaining method calls, and then ending with a call to ```.end();```

### Simple routes

For simple routes you can use the ```match()``` method to define basic patterns that map to controllers and actions. By using the ```get()```, ```post()```, ```put()```, or ```delete()``` helpers, you can create routes that only match specific HTTP verbs. If you prefer, you can just pass a list of HTTP verbs to the ```methods``` parameter of the ```match()``` method to have the same effect.

The ```root()``` method will create a route that matches an empty string (or the root of the site). By default, this route will match all HTTP verbs.

Common arguments for route creation functions:

* ```name``` - a name for the created route. Will be used in path and URL view helpers. Does not have to be unique.
* ```pattern``` - the pattern to match against a request's path. May use variables in square brackets per CFWheels documentation. Defaults to hyphenized ```name```.
* ```methods``` - list of HTTP verbs to be allowed for the route. ```method``` is an alias.
* ```module``` - CFC path to be appended to controller name. Uses dot notation.
* ```controller``` - controller that this route will map to.
* ```action``` - action that this route will map to. Defaults to ```name```.
* ```to``` - shorthand way to specify ```controller``` and ```action``` separated by ```#``` character. (eg. ```items##index```)

The ```wildcard()``` helper will create a set of routes that match any controller, action, or key. They are identical to the default CFWheels routes:

* ```/[controller]/[action]/[key]```
* ```/[controller]/[action]```
* ```/[controller]```

### Scoping

When a set of routes share common arguments, it makes sense to use the family of scoping methods. The most basic scope is started by passing arguments to ```scope()```, which will then take effect until ```end()``` is called. All routes nested between the opening and closing method calls will have the scoped arguments applied to them. The following arguments are allowed:

* ```name``` - a route name prefix. Most of the time, it will be prepended to the ```name``` route argument.
* ```path``` - a pattern string to be prepended to the ```pattern``` route argument.
* ```module``` - a module to be prepended (through dot notation) to the ```module``` route argument.
* ```controller``` - the controller to use in the nested routes. Can still be overridden.

Two common use cases are setting up many routes for a single controller, and creating a namespace with a sub-folder of controllers. Note that __none of the scoping operations actually create routes__. They just set up common arguments for routes created within the scope.

#### Controllers

The ```controller()``` scope helper allows for the ```controller```, ```name```, and ```path``` parameters to be set in a single call. The method takes ```controller``` as the first parameter, and defaults ```path``` and ```name``` to hyphenized and non-hyphenized values of ```controller```, respectively.

So, calling ```controller("favoriteSites")``` is the same as calling ```scope(controller="favoriteSites", name="favoriteSites", pattern="favorite-sites")```.

#### Namespaces

The ```namespace()``` scope helpers allows for the ```module```, ```name```, and ```path``` parameters to be set in a single call. The method takes ```module``` as the first parameter, and defaults ```path``` and ```name``` to hyphenized and non-hyphenized values of ```module```, respectively.

So, calling ```namespace("admin")``` is the same as calling ```scope(module="admin", name="admin", pattern="admin")```.

Remember that the ```module``` argument will be appended to the controller name used in nested routes. This means that if you create a route against the ```item``` controller, it will actually map to the ```admin.item``` controller. You would need to store this controller CFC at ```/controllers/admin/Item.cfc```.

### Resources

_Documentation will be available soon._

## View Helpers

Using the standard ```linkTo``` and ```urlFor``` link helpers will find the appropriate route for the controller and action passed in. However, another option is to use the ColdRoute path and URL helpers.

For each named route in your application, there will be two methods generated to assist you in using that route. For example, if a route is named _items_, then there will be ```itemsPath()``` and ```itemsUrl()``` methods generated for you. They will return relative and absolute URLs for that route, respectively.

### Parameters

Any valid ```urlFor``` parameters may be passed into the path helpers, except ```route``` and ```onlyPath```. There is an added bonus of automatically mapping unnamed arguments to the variables required for the route.

If you had a named route like ```get(name="editItemComment", pattern="/items/[itemKey]/comments/[key]/edit")``` in your routes file, then you could call ```editItemCommentPath(237, 15)``` to generate ```/items/237/comments/15/edit```.

You do not even have to pass static values to the helpers. In fact, you can just as easily pass model objects: ```editItemCommentPath(item, comment)```. The path helper will call ```toParam()``` on any model objects that are passed in. ```toParam()``` defaults to calling the CFWheels ```key()``` method, but can be overridden in your model CFCs as needed.

### HTTP verbs

Remember that routes can also require specific HTTP verbs to be correctly matched. You may notice that the path and URL helpers above only generate paths for routes. It is up to the developer to specify the correct HTTP method to use for forms and links.

However, most web browsers do not support the PUT or DELETE methods. There is special logic used in ColdRoute for determining the HTTP verb of the request which will allow a ```_method``` form parameter to override the HTTP verb, as long as the actual request is a POST.

For forms, you just have to pass a hidden field to override the method:

```coldfusion
<form action="#updateItemPath(item)#" method="post">
	<input type="hidden" name="_method" value="put" />
	<!-- form fields -->
</form>
```

Links are a little more complex, since they cannot be forced to be POST requests. A good way to handle special links is to set a ```data-method``` attribute, and then bind the click action of the link to generate and submit a form with a hidden ```_method``` field. The jQuery UJS script will do this automatically for you.

```coldfusion
<a href="#deleteItemPath(item)#" data-method="delete" data-confirm="Delete This Item?" rel="nofollow">Delete</a>
```

Or, using the ColdRoute ```linkTo``` overrides:

```coldfusion
#linkTo(text="Delete", href=deleteItemPath(item), method="delete", confirm="Delete This Item?")# 
```

## Example Routes

__Note:__ This can be greatly improved through the use of resources, which will be covered in the future.

```coldfusion
drawRoutes()

	// administration side
	.namespace("admin")
		.controller("blog")
			.get("new")
			.post("create")
			.get(name="show", pattern="show/[key]")
			.get(name="edit", pattern="edit/[key]")
			.put(name="update", pattern="update/[key]")
			.delete(name="delete", pattern="delete/[key]")
			.root(action="index")
		.end()
	.end()
	
	// public side
	.controller("blog")
		.get(name="show", pattern="[key]")
		.root(action="index")
	.end()
	
	// default routes
	.wildcard()
	.root(to="blog##index")
.end();
```

This would create the following routes:

* ```GET /admin/blog/new``` => ```admin.blog#new```
* ```POST /admin/blog/create``` => ```admin.blog#create```
* ```GET /admin/blog/show/[key]``` => ```admin.blog#show```
* ```GET /admin/blog/edit/[key]``` => ```admin.blog#edit```
* ```PUT /admin/blog/update/[key]``` => ```admin.blog#update```
* ```DELETE /admin/blog/delete/[key]``` => ```admin.blog#delete```
* ```/admin/blog``` => ```admin.blog#index```
* ```GET /blog/[key]``` => ```blog#show```
* ```GET /blog``` => ```blog#index```
* ```/[controller]/[action]/[key]``` => ```[controller]#[action]```
* ```/[controller]/[action]``` => ```[controller]#[action]```
* ```/[controller]``` => ```[controller]#index```
* ```/``` => ```blog#index```

More documentation to come...