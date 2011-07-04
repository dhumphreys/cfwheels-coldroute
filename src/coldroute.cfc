<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfscript>
			this.version = "1.1,1.2";
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
			var loc = {};
			loc.key = "";
			loc.primaryKeys = ListToArray(primaryKeys());
			loc.iEnd = ArrayLen(loc.primaryKeys);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				loc.key = ListAppend(loc.key, this[loc.primaryKeys[loc.i]]);
			return loc.key;
		</cfscript>
	</cffunction>
	
	<cffunction name="$getRequestMethod" mixin="dispatch" returntype="string" access="public">
		<cfscript>
			var loc = {};
			if (cgi.request_method EQ "post") {
				loc.method = StructKeyExists(form, "_method") ? form["_method"] : StructKeyExists(url, "_method") ? url["_method"] : "";
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

					if (ListLen(arguments.path, "/") gte ListLen(loc.currentRoute, "/") && loc.currentRoute != "") {
						
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
</cfcomponent>