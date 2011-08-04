<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfscript>
			var loc = {};
			
			// cfwheels version string
			this.version = "1.1.1,1.1.2,1.1.3,1.2";
			
			// get cfwheels plugin prefix
			loc.prefix = ListChangeDelims(application.wheels.webPath & application.wheels.pluginPath, ".", "/");
			
			// initialize coldroute mapper
			application.wheels.coldroute = CreateObject("component", "#loc.prefix#.coldroute.lib.Mapper").init();
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="drawRoutes" mixin="application" returntype="struct" output="false" access="public" hint="Start drawing routes">
		<cfargument name="restful" type="boolean" default="true" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#arguments.restful#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfreturn application.wheels.coldroute.draw(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="toParam" mixin="model" returntype="any" access="public" output="false" hint="Turn model object into key acceptable for use in URL. Can be overridden per model.">
		<cfscript>
			
			// call wheels key() method by default
			return key();
		</cfscript>
	</cffunction>
	
	<cffunction name="linkTo" mixin="controller" returntype="any" access="public" output="false" hint="Allow data-method and data-confirm on links">
		<cfscript>
			var loc = {};
			var coreLinkTo = core.linkTo;
			
			// look for passed in rest method
			if (StructKeyExists(arguments, "method")) {
				
				// if dealing with delete, keep robots from following link
				if (arguments.method EQ "delete") {
					if (NOT StructKeyExists(arguments, "rel"))
						arguments.rel = "";
					arguments.rel = ListAppend(arguments.rel, "no-follow", " ");
				}
				
				// put the method in a data attribute
				arguments["data-method"] = arguments.method;
				StructDelete(arguments, "method");
			}
			
			// set confirmation text for link
			if (StructKeyExists(arguments, "confirm")) {
				arguments["data-confirm"] = arguments.confirm;
				StructDelete(arguments, "confirm");
			}
			
			// set up remote links
			if (StructKeyExists(arguments, "remote")) {
				arguments["data-remote"] = arguments.remote;
				StructDelete(arguments, "remote");
			}
			
			// hyphenize any other data attributes
			for (loc.key in arguments) {
				if (REFind("^data[A-Z]", loc.key)) {
					arguments[hyphenize(loc.key)] = arguments[loc.key];
					StructDelete(arguments, loc.key);
				}
			}
			
			return coreLinkTo(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="urlFor" mixin="controller" returntype="string" access="public" output="false" hint="Look up actual route paths instead of providing default Wheels path generation">
		<cfscript>
			var loc = {};
			var coreUrlFor = core.urlFor;
			
			// try looking up exact route if controller and action are set
			if ((NOT StructKeyExists(arguments, "route") OR arguments.route EQ "") AND StructKeyExists(arguments, "action")) {
				
				// fill in controller if it is not set
				if (NOT StructKeyExists(arguments, "controller") OR arguments.controller EQ "")
					arguments.controller = variables.params.controller;
				
				// determine key and look up cache structure
				loc.key = arguments.controller & "##" & arguments.action;
				loc.cache = $urlForCache();
				
				// if route has already been found, just use it
				if (StructKeyExists(loc.cache, loc.key)) {
					arguments.route = loc.cache[loc.key];
					
				} else {
					
					// loop over routes to find matching one
					loc.iEnd = ArrayLen(application.wheels.routes);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
						loc.curr = application.wheels.routes[loc.i];
						
						// if found, cache the route name, set up arguments, and break from loop
						if (loc.curr.controller EQ arguments.controller AND loc.curr.action EQ arguments.action) {
							arguments.route = application.wheels.routes[loc.i].name;
							loc.cache[loc.key] = arguments.route;
							break;
						}
					}
				}
			}
			
			// call core method
			return coreUrlFor(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="$urlForCache" mixin="global" returntype="struct" access="public" hint="Lazy-create a request-level cache for found routes">
		<cfscript>
			if (NOT StructKeyExists(request.wheels, "urlForCache"))
				request.wheels.urlForCache = {};
			return request.wheels.urlForCache;
		</cfscript>
	</cffunction>
	
	<cffunction name="$getRequestMethod" mixin="dispatch" returntype="string" access="public" hint="Determine HTTP verb used in request">
		<cfscript>
			
			// if request is a post, check for alternate verb
			if (cgi.request_method EQ "post" AND StructKeyExists(form, "_method"))
				return form["_method"];
			
			return cgi.request_method;
		</cfscript>
	</cffunction>

	<!--- logic from restful-routes plugin by James Gibson --->
	<cffunction name="$findMatchingRoute" mixin="dispatch" returntype="struct" access="public" hint="Help Wheels match routes using path and HTTP method">
		<cfargument name="path" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// get HTTP verb used in request
			loc.requestMethod = $getRequestMethod();

			// loop over wheels routes
			loc.iEnd = ArrayLen(application.wheels.routes);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.format = false;
				
				// check for a supplied format parameter
				if (StructKeyExists(application.wheels.routes[loc.i], "format"))
					loc.format = application.wheels.routes[loc.i].format;

				// grab the current route's pattern
				loc.routeStruct = application.wheels.routes[loc.i];
				loc.currentRoute = application.wheels.routes[loc.i].pattern;

				// if route pattern is a star, match found
				if (loc.currentRoute EQ "*") {
					loc.returnValue = application.wheels.routes[loc.i];
					break;
					
				// if route pattern and path are both 
				} else if (arguments.path EQ "" AND loc.currentRoute EQ "") {
					loc.returnValue = application.wheels.routes[loc.i];
					break;
					
				} else {
					
					// set up conditions to be met
					loc.matchMethod = false;
					loc.matchVariables = true;

					if (ListLen(arguments.path, "/") EQ ListLen(loc.currentRoute, "/") AND loc.currentRoute NEQ "") {
						
						// check for matching variables
						loc.jEnd = ListLen(loc.currentRoute, "/");
						for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++) {
							loc.item = ListGetAt(loc.currentRoute, loc.j, "/");
							loc.thisRoute = ReplaceList(loc.item, "[,]", ",");
							loc.thisURL = ListGetAt(arguments.path, loc.j, "/");
							if (Left(loc.item, 1) NEQ "[" AND loc.thisRoute NEQ loc.thisURL)
								loc.matchVariables = false;
						}

						// now check to make sure the method is correct, skip this if not definied for the route
						if (StructKeyExists(loc.routeStruct, "methods")){
							if (ListFindNoCase(loc.routeStruct.methods, loc.requestMethod))
								loc.matchMethod = true;
							
						// assume that the method is correct if not provided
						} else {
							loc.matchMethod = true;
						}

						// if both method and variables match
						if (loc.matchMethod AND loc.matchVariables) {
							
							// set route to be returned
							loc.returnValue = Duplicate(application.wheels.routes[loc.i]);
							if (Len($getFormatFromRequest(pathInfo=arguments.path)) AND NOT IsBoolean(loc.format))
								loc.returnValue[ReplaceList(loc.format, "[,]", "")] = $getFormatFromRequest(pathInfo=arguments.path);
							break;
						}
					}
				}
			}
			
			// throw error if not route was found
			if (NOT StructKeyExists(loc, "returnValue"))
				$throw(type="Wheels.RouteNotFound", message="Wheels couldn't find a route that matched this request.", extendedInfo="Make sure there is a route setup in your 'config/routes.cfm' file that matches the '#arguments.path#' request.");
		</cfscript>
		<cfreturn loc.returnValue />
	</cffunction>
	
	<!--- TODO: patch this in wheels code --->
	<cffunction name="$getPathFromRequest" returntype="string" access="public" hint="Don't split incoming paths at `.` like Wheels does">
		<cfargument name="pathInfo" type="string" required="true">
		<cfargument name="scriptName" type="string" required="true">
		<cfscript>
			var returnValue = "";
			// we want the path without the leading "/" so this is why we do some checking here
			if (arguments.pathInfo == arguments.scriptName || arguments.pathInfo == "/" || arguments.pathInfo == "")
				returnValue = "";
			else
				returnValue = Right(arguments.pathInfo, Len(arguments.pathInfo)-1);
		</cfscript>
		<cfreturn returnValue>
	</cffunction>
	
	<cffunction name="$initControllerClass" mixin="controller" returntype="any" access="public" hint="Automatically call filter to create named route methods">
		<cfargument name="name" type="string" required="false" default="">
		<cfscript>
			var coreInit = core.$initControllerClass;
			coreInit(argumentCollection=arguments);
			filters(through="$registerNamedRouteMethods");
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="$registerNamedRouteMethods" mixin="controller" returntype="void" access="public" hint="Filter that sets up named route helper methods">
		<cfscript>
			var loc = {};
			for (loc.key in application.wheels.namedRoutePositions) {
				variables[loc.key & "Path"] = $namedRouteMethod;
				variables[loc.key & "Url"] = $namedRouteMethod;
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="$namedRouteMethod" mixin="controller" returntype="string" access="public" output="false" hint="Body of all named route helper methods">
		<cfscript>
			var loc = {};
			
			// FIX: numbered arguments with StructDelete() are breaking in CF 9.0.1, this hack fixes it
			arguments = Duplicate(arguments);
			
			// determine route name and path type
			arguments.route = GetFunctionCalledName();
			if (REFindNoCase("Path$", arguments.route)) {
				arguments.route = REReplaceNoCase(arguments.route, "^(.+)Path$", "\1");
				arguments.onlyPath = true;
			} else if (REFindNoCase("Url$", arguments.route)) {
				arguments.route = REReplaceNoCase(arguments.route, "^(.+)Url$", "\1");
				arguments.onlyPath = false;
			}
			
			// get the matching route and any required variables
			if (StructKeyExists(application.wheels.namedRoutePositions, arguments.route)) {
				loc.routePos = application.wheels.namedRoutePositions[arguments.route];
				
				// for backwards compatibility, allow loc.routePos to be a list
				if (IsArray(loc.routePos))
					loc.pos = loc.routePos[1];
				else
					loc.pos = ListFirst(loc.routePos);
				
				// grab first route found
				// todo: don't just accept the first route found
				loc.route = application.wheels.routes[loc.pos];
				loc.vars = ListToArray(loc.route.variables);
			
				// loop over variables needed for route
				loc.iEnd = ArrayLen(loc.vars);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
					loc.value = false;
					loc.key = loc.vars[loc.i];
					
					// try to find the correct argument
					if (StructKeyExists(arguments, loc.key)) {
						loc.value = arguments[loc.key];
						StructDelete(arguments, loc.key);
					} else if (StructKeyExists(arguments, loc.i)) {
						loc.value = arguments[loc.i];
						StructDelete(arguments, loc.i);
					}
						
					// use the value if it is simple
					if (IsSimpleValue(loc.value) AND loc.value NEQ false) {
						arguments[loc.key] = loc.value;
					} else if (IsObject(loc.value)) {
						
						// if the passed in object is new, link to the plural REST route instead
						if (loc.value.isNew()) {
							if (StructKeyExists(application.wheels.namedRoutePositions, pluralize(arguments.route))) {
								arguments.route = pluralize(arguments.route);
								break;
							}
							
						// otherwise, use the Model#toParam method
						} else {
							arguments[loc.key] = loc.value.toParam();
						}
					}
				}
			}
			
			// return correct url with arguments set
			return urlFor(argumentCollection=arguments);
		</cfscript>
	</cffunction>
</cfcomponent>