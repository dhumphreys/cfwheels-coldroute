<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfscript>
			this.version = "1.1.1,1.1.2,1.1.3,1.2";
			application.wheels.coldRoute = CreateObject("component", "/plugins.coldroute.coldroute.ColdRoute").init();
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="drawRoutes" mixin="application" returntype="struct" access="public" hint="Start drawing routes">
		<cfargument name="restful" type="boolean" default="true" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#arguments.restful#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfreturn application.wheels.coldRoute.draw(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="toKey" mixin="model" returntype="any" access="public" hint="Turn model object into key acceptable for use in URL. Can be overridden per model.">
		<cfscript>
			
			// call wheels key() method by default
			return key();
		</cfscript>
	</cffunction>
	
	<cffunction name="linkTo" mixin="controller" returntype="any" access="public" hint="">
		<cfscript>
			
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
			
			return core.linkTo(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="$getRequestMethod" mixin="dispatch" returntype="string" access="public">
		<cfscript>
			var loc = {};
			if (cgi.request_method EQ "post") {
				loc.method = StructKeyExists(form, "_method") ? form["_method"] : "";
				switch (loc.method) {
					case "put": return "put"; break;
					case "delete": return "delete"; break;
					default: return "post";
				}
			} else {
				return LCase(cgi.request_method);
			}
		</cfscript>
	</cffunction>

	<!--- logic from restful-routes plugin by James Gibson --->
	<cffunction name="$findMatchingRoute" mixin="dispatch" returntype="struct" access="public" output="false">
		<cfargument name="path" type="string" required="true">
		<cfscript>
			var loc = {};
			loc.requestMethod = $getRequestMethod();

			loc.iEnd = ArrayLen(application.wheels.routes);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.format = false;
				if (StructKeyExists(application.wheels.routes[loc.i], "format"))
					loc.format = application.wheels.routes[loc.i].format;

				loc.routeStruct = application.wheels.routes[loc.i];
				loc.currentRoute = application.wheels.routes[loc.i].pattern;

				// still make sure we have the right length route
				if (loc.currentRoute == "*") {
					loc.returnValue = application.wheels.routes[loc.i];
					break;
				} else if (arguments.path == "" && loc.currentRoute == "") {
					loc.returnValue = application.wheels.routes[loc.i];
					break;
				} else {
					loc.match = {method = false, variables = true};

					if (ListLen(arguments.path, "/") EQ ListLen(loc.currentRoute, "/") && loc.currentRoute != "") {
						
						// check for matching variables
						loc.jEnd = ListLen(loc.currentRoute, "/");
						for (loc.j=1; loc.j <= loc.jEnd; loc.j++) {
							loc.item = ListGetAt(loc.currentRoute, loc.j, "/");
							loc.thisRoute = ReplaceList(loc.item, "[,]", ",");
							loc.thisURL = ListGetAt(arguments.path, loc.j, "/");
							if (Left(loc.item, 1) != "[" && loc.thisRoute != loc.thisURL)
								loc.match.variables = false;
						}

						// now check to make sure the method is correct, skip this if not definied for the route
						if (StructKeyExists(loc.routeStruct, "methods")){
							if (ListFind(loc.routeStruct.methods, loc.requestMethod))
								loc.match.method = true;
						} else {
							// assume that the method is correct if not provided
							loc.match.method = true;
						}

						if (loc.match.method AND loc.match.variables) {
							loc.returnValue = Duplicate(application.wheels.routes[loc.i]);
							if (Len($getFormatFromRequest(pathInfo=arguments.path)) AND NOT IsBoolean(loc.format))
								loc.returnValue[ReplaceList(loc.format, "[,]", "")] = $getFormatFromRequest(pathInfo=arguments.path);
							break;
						}
					}
				}
			}
			if (NOT StructKeyExists(loc, "returnValue"))
				$throw(type="Wheels.RouteNotFound", message="Wheels couldn't find a route that matched this request.", extendedInfo="Make sure there is a route setup in your 'config/routes.cfm' file that matches the '#arguments.path#' request.");
		</cfscript>
		<cfreturn loc.returnValue>
	</cffunction>
	
	<cffunction name="$getPathFromRequest" returntype="string" access="public" output="false">
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
	
	<cffunction name="$initControllerClass" returntype="any" access="public" output="false">
		<cfargument name="name" type="string" required="false" default="">
		<cfscript>
			
			// call core init method
			core.$initControllerClass(argumentCollection=arguments);
			
			// set up filter to create named route methods
			filters(through="$registerNamedRouteMethods");
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="$registerNamedRouteMethods" mixin="controller" returntype="void" access="public">
		<cfscript>
			var loc = {};
			for (loc.key in application.wheels.namedRoutePositions)
				variables[loc.key & "Path"] = variables[loc.key & "Url"] = $namedRouteMethod;
		</cfscript>
	</cffunction>
	
	<cffunction name="$namedRouteMethod" mixin="controller" returntype="string" access="public">
		<cfscript>
			var loc = {};
			
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
				
				// todo: don't just accept the first route found
				loc.pos = IsArray(loc.routePos) ? loc.routePos[1] : ListFirst(loc.routePos);
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
							
						// otherwise, use the Model#toKey method
						} else {
							arguments[loc.key] = loc.value.toKey();
						}
					}
				}
			}
			
			// return correct url with arguments set
			return urlFor(argumentCollection=arguments);
		</cfscript>
	</cffunction>
</cfcomponent>