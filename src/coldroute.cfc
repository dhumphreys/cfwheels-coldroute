<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfscript>
			var loc = {};
			
			// cfwheels version string
			this.version = "1.1,1.1.1,1.1.2,1.1.3,1.1.4,1.1.5";
			
			// get cfwheels plugin prefix
			loc.prefix = ListChangeDelims(application.wheels.webPath & application.wheels.pluginPath, ".", "/");
			
			// initialize coldroute mapper
			application.wheels.coldroute = CreateObject("component", "#loc.prefix#.coldroute.lib.Mapper").init();
			
			// set wheels setting for resource controller naming
			// NOTE: options are singular, plural, or name
			if (NOT StructKeyExists(application.wheels, "resourceControllerNaming"))
				application.wheels.resourceControllerNaming = "plural";
			
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

	<cffunction name="URLFor" mixin="controller" returntype="string" access="public" output="false">
		<cfargument name="route" type="string" required="false" default="" hint="Name of a route that you have configured in `config/routes.cfm`.">
		<cfargument name="controller" type="string" required="false" default="" hint="Name of the controller to include in the URL.">
		<cfargument name="action" type="string" required="false" default="" hint="Name of the action to include in the URL.">
		<cfargument name="key" type="any" required="false" default="" hint="Key(s) to include in the URL.">
		<cfargument name="params" type="string" required="false" default="" hint="Any additional params to be set in the query string.">
		<cfargument name="anchor" type="string" required="false" default="" hint="Sets an anchor name to be appended to the path.">
		<cfargument name="onlyPath" type="boolean" required="false" hint="If `true`, returns only the relative URL (no protocol, host name or port).">
		<cfargument name="host" type="string" required="false" hint="Set this to override the current host.">
		<cfargument name="protocol" type="string" required="false" hint="Set this to override the current protocol.">
		<cfargument name="port" type="numeric" required="false" hint="Set this to override the current port number.">
		<cfargument name="$URLRewriting" type="string" required="false" default="#application.wheels.URLRewriting#">
		<cfscript>
			var loc = {};
			loc.coreVariables = "controller,action,key,format";
			loc.returnValue = $args(name="URLFor", args=arguments, cachable=true);
			if (StructKeyExists(loc, "returnValue"))
				return loc.returnValue;
				
			// error if host or protocol are passed with onlyPath=true
			if (application.wheels.showErrorInformation AND arguments.onlyPath AND (Len(arguments.host) OR Len(arguments.protocol)))
				$throw(type="Wheels.IncorrectArguments", message="Can't use the `host` or `protocol` arguments when `onlyPath` is `true`.", extendedInfo="Set `onlyPath` to `false` so that `linkTo` will create absolute URLs and thus allowing you to set the `host` and `protocol` on the link.");
			
			// Look up actual route paths instead of providing default Wheels path generation
			if (arguments.route EQ "" AND arguments.action NEQ "") {
				if (arguments.controller EQ "")
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
						if (StructKeyExists(loc.curr, "controller") AND loc.curr.controller EQ arguments.controller AND StructKeyExists(loc.curr, "action") AND loc.curr.action EQ arguments.action) {
							arguments.route = application.wheels.routes[loc.i].name;
							loc.cache[loc.key] = arguments.route;
							break;
						}
					}
				}
			}
			
			// look up route pattern to use
			if (arguments.route NEQ "") {
				loc.route = $findRoute(argumentCollection=arguments);
				loc.variables = loc.route.variables;
				loc.returnValue = loc.route.pattern;
			
			// use default route pattern
			} else {
				loc.route = {};
				loc.variables = loc.coreVariables;
				loc.returnValue = "/[controller]/[action]/[key].[format]";
				
				// set controller and action based on controller params
				if (StructKeyExists(variables, "params")) {
					if (arguments.action EQ "" AND StructKeyExists(variables.params, "action") AND (arguments.controller NEQ "" OR arguments.key NEQ "" OR StructKeyExists(arguments, "format")))
						arguments.action = variables.params.action;
					if (arguments.controller EQ "" AND StructKeyExists(variables.params, "controller"))
						arguments.controller = variables.params.controller;
				}
			}
			
			// replace pattern if there is no rewriting enabled
			if (arguments.$URLRewriting EQ "Off") {
				loc.variables = ListPrepend(loc.variables, loc.coreVariables);
				loc.returnValue = "?controller=[controller]&action=[action]&key=[key]&format=[format]";
			}
			
			// replace each params variable with the correct value
			loc.iEnd = ListLen(loc.variables);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.property = ListGetAt(loc.variables, loc.i);
				loc.reg = "\[\*?#loc.property#\]";
				
				// read necessary variables from different sources
				if (StructKeyExists(arguments, loc.property) AND Len(arguments[loc.property]))
					loc.value = arguments[loc.property];
				else if (StructKeyExists(loc.route, loc.property))
					loc.value = loc.route[loc.property];
				else if (arguments.route NEQ "" AND arguments.$URLRewriting NEQ "Off")
					$throw(type="Wheels", message="Incorrect Arguments", extendedInfo="The route chosen by Wheels `#loc.route.name#` requires the argument `#loc.property#`. Pass the argument `#loc.property#` or change your routes to reflect the proper variables needed.");
				else
					continue;
					
				// if value is a model object, get its key value
				if (IsObject(loc.value))
					loc.value = loc.value.toParam();
				
				// if property is not in pattern, store it in the params argument
				if (NOT REFind(loc.reg, loc.returnValue)) {
					if (NOT	ListFindNoCase(loc.coreVariables, loc.property))
						arguments.params = ListAppend(arguments.params, "#loc.property#=#loc.value#", "&");
					continue;
				}
				
				// transform value before setting it in pattern
				if (loc.property EQ "controller" OR loc.property EQ "action")
					loc.value = hyphenize(loc.value);
				else if (application.wheels.obfuscateUrls)
					loc.value = obfuscateParam(loc.value);
				
				loc.returnValue = REReplace(loc.returnValue, loc.reg, loc.value);
			}
			
			// clean up unused keys in pattern
			loc.returnValue = REReplace(loc.returnValue, "((&|\?)\w+=|/|\.)\[\*?\w+\]", "", "ALL");
			
			// apply anchor and additional parameters
			if (Len(arguments.params))
				loc.returnValue = loc.returnValue & $constructParams(params=arguments.params, $URLRewriting=arguments.$URLRewriting);
			if (Len(arguments.anchor))
				loc.returnValue = loc.returnValue & "##" & arguments.anchor;
	
			// apply needed path prefix depending on rewrite style
			if (arguments.$URLRewriting EQ "Partial")
				loc.returnValue = application.wheels.rewriteFile & loc.returnValue;
			else if (arguments.$URLRewriting EQ "Off")
				loc.returnValue = "index.cfm" & loc.returnValue;
			loc.returnValue = application.wheels.webPath & loc.returnValue;
			loc.returnValue = Replace(loc.returnValue, "//", "/", "ALL");
	
			// prepend necessary url information
			if (NOT arguments.onlyPath){
				if (arguments.port NEQ 0)
					loc.returnValue = ":" & arguments.port & loc.returnValue; // use the port that was passed in by the developer
				else if (request.cgi.server_port NEQ 80 AND request.cgi.server_port NEQ 443)
					loc.returnValue = ":" & request.cgi.server_port & loc.returnValue; // if the port currently in use is not 80 or 443 we set it explicitly in the URL
				if (Len(arguments.host))
					loc.returnValue = arguments.host & loc.returnValue;
				else
					loc.returnValue = request.cgi.server_name & loc.returnValue;
				if (Len(arguments.protocol))
					loc.returnValue = arguments.protocol & "://" & loc.returnValue;
				else
					loc.returnValue = SpanExcluding(LCase(request.cgi.server_protocol), "/") & "://" & loc.returnValue;
			}
		</cfscript>
		<cfreturn loc.returnValue />
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

	<cffunction name="$loadRoutes" mixin="application,dispatch" returntype="void" access="public" output="false" hint="Prevent race condition when reloading routes in design mode">
		<cfset var coreLoadRoutes = core.$loadRoutes />
		<cflock name="coldrouteLoadRoutes" timeout="5" type="exclusive">
			<cfset coreLoadRoutes() />
		</cflock>
	</cffunction>

	<cffunction name="$findMatchingRoute" mixin="dispatch" returntype="struct" access="public" hint="Help Wheels match routes using path and HTTP method">
		<cfargument name="path" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// get HTTP verb used in request
			loc.requestMethod = $getRequestMethod();

			// loop over wheels routes
			loc.iEnd = ArrayLen(application.wheels.routes);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.route = application.wheels.routes[loc.i];
				
				// if method doesn't match, skip this route
				if (StructKeyExists(loc.route, "methods") AND NOT ListFindNoCase(loc.route.methods, loc.requestMethod))
					continue;
				
				// make sure route has been converted to regex
				if (NOT StructKeyExists(loc.route, "regex"))
					loc.route.regex = application.wheels.coldroute.patternToRegex(loc.route.pattern);
				
				// if route matches regular expression, set it for return
				if (REFindNoCase(loc.route.regex, arguments.path) OR (arguments.path EQ "" AND loc.route.pattern EQ "/")) {
					loc.returnValue = Duplicate(application.wheels.routes[loc.i]);
					break;
				}
			}
			
			// throw error if not route was found
			if (NOT StructKeyExists(loc, "returnValue"))
				$throw(type="Wheels.RouteNotFound", message="Wheels couldn't find a route that matched this request.", extendedInfo="Make sure there is a route setup in your 'config/routes.cfm' file that matches the '#arguments.path#' request.");
		</cfscript>
		<cfreturn loc.returnValue />
	</cffunction>
	
	<cffunction name="$mergeRoutePattern" returntype="struct" access="public" output="false" mixin="dispatch,controller" hint="Pull route variables out of path">
		<cfargument name="params" type="struct" required="true">
		<cfargument name="route" type="struct" required="true">
		<cfargument name="path" type="string" required="true">
		<cfscript>
			var loc = {};
			loc.matches = REFindNoCase(arguments.route.regex, arguments.path, 1, true);
			loc.iEnd = ArrayLen(loc.matches.pos);
			for (loc.i = 2; loc.i LTE loc.iEnd; loc.i++) {
				loc.key = ListGetAt(arguments.route.variables, loc.i - 1);
				arguments.params[loc.key] = Mid(arguments.path, loc.matches.pos[loc.i], loc.matches.len[loc.i]);
			}
			return arguments.params;
		</cfscript>
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
					loc.key = loc.vars[loc.i];
					
					// try to find the correct argument
					if (StructKeyExists(arguments, loc.key)) {
						loc.value = arguments[loc.key];
						StructDelete(arguments, loc.key);
					} else if (StructKeyExists(arguments, loc.i)) {
						loc.value = arguments[loc.i];
						StructDelete(arguments, loc.i);
					}
						
					// if value was passed in
					if (StructKeyExists(loc, "value")) {
						
						// just assign simple values
						if (NOT IsObject(loc.value)) {
							arguments[loc.key] = loc.value;
							
						// if object, do special processing
						} else {
							
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
						
						// remove value for next loop
						StructDelete(loc, "value");
					}
				}
			}
			
			// return correct url with arguments set
			return urlFor(argumentCollection=arguments);
		</cfscript>
	</cffunction>
</cfcomponent>