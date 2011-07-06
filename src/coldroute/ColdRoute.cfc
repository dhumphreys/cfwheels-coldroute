<cfcomponent output="false">
	<cfinclude template="/wheels/global/functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="restful" type="boolean" default="true" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#arguments.restful#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfscript>
			
			// set up control variables
			variables.scopeStack = [];
			variables.routes = [];
			variables.restful = arguments.restful;
			variables.methods = arguments.restful OR arguments.methods;
			
			
			// fix naming collision with cfwheels get() method
			this.get = variables.get = variables.$get;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="draw" returntype="struct" access="public">
		<cfargument name="restful" type="boolean" default="#variables.restful#" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#variables.methods#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfscript>
			variables.restful = arguments.restful;
			variables.methods = arguments.restful OR arguments.methods;
			ArrayAppend(scopeStack, {$call="draw"});
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="end" returntype="struct" access="public">
		<cfscript>
			
			// if last action was a resource, set up REST routes
			// TODO: consider non-restful routes
			if (scopeStack[1].$call EQ "resources") {
				$get(pattern="new", action="new", name="new", $singular=true);
				$get(pattern="[key]/edit", action="edit", name="edit", $singular=true);
				$get(pattern="[key]", action="show", $singular=true);
				put(pattern="[key]", action="update", $singular=true);
				delete(pattern="[key]", action="delete", $singular=true);
				$get(pattern="", action="index");
				post(pattern="", action="create");
			} else if (scopeStack[1].$call EQ "resource") {
				$get(pattern="new", action="new", name="new");
				$get(pattern="edit", action="edit", name="edit");
				$get(pattern="", action="show");
				post(pattern="", action="create");
				put(pattern="", action="update");
				delete(pattern="", action="delete");
			}
			
			// remove top of stack to end nesting
			ArrayDeleteAt(scopeStack, 1);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="routes" returntype="array" access="public">
		<cfscript>
			return variables.routes;
		</cfscript>
	</cffunction>
	
	<!---------------------
	--- Simple Matching ---
	---------------------->
	
	<cffunction name="match" returntype="struct" access="public" hint="Match a url">
		<cfargument name="name" type="string" required="false" />
		<cfargument name="pattern" type="string" required="false" />
		<cfargument name="to" type="string" required="false" />
		<cfargument name="methods" type="string" required="false" />
		<cfargument name="module" type="string" required="false" />
		<cfargument name="$singular" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			
			// pull arguments from scope stack
			StructAppend(arguments, scopeStack[1], false);
			
			// interpret 'to' as 'controller#action'
			if (StructKeyExists(arguments, "to")) {
				arguments.controller = ListFirst(arguments.to, "##");
				arguments.action = ListLast(arguments.to, "##");
				StructDelete(arguments, "to");
			}
			
			// pull name from arguments, or make it blank
			if (NOT StructKeyExists(arguments, "name")) {
				loc.name = "";
			} else {
				loc.name = arguments.name;
				
				// guess pattern and/or action
				if (NOT StructKeyExists(arguments, "pattern"))
					arguments.pattern = hyphenize(arguments.name);
				if (NOT StructKeyExists(arguments, "action") AND Find("[action]", arguments.pattern) EQ 0)
					arguments.action = arguments.name;
			}
			
			// die if pattern is not defined
			if (NOT StructKeyExists(arguments, "pattern"))
				throw("Either 'pattern' or 'name' must be defined.");
			
			// accept either 'method' or 'methods'
			if (StructKeyExists(arguments, "method")) {
				arguments.methods = arguments.method;
				StructDelete(arguments, "method");
			}
			
			// remove ''methods' argument if settings disable it
			if (NOT variables.methods AND StructKeyExists(arguments, "methods"))
				StructDelete(arguments, "methods");
			
			// add scoped path to pattern
			if (StructKeyExists(arguments, "path")) {
				arguments.pattern = arguments.path & "/" & arguments.pattern;
				StructDelete(arguments, "path");
			}
			
			// fix possible path string issues
			arguments.pattern = Replace(arguments.pattern, "//", "/", "ALL");
			arguments.pattern = REReplace(arguments.pattern, "/([^/]+)/$", "/\1");
			arguments.pattern = REReplace(arguments.pattern, "^([^/]+)", "/\1");
			
			// process module namespace
			if (StructKeyExists(arguments, "module")) {
				
				// append module to route name
				if (loc.name NEQ "" OR StructKeyExists(arguments, "resource"))
					loc.name = ListAppend(loc.name, Replace(arguments.module, ".", ",", "ALL"));
				
				// append to controller or leave module variable set
				if (StructKeyExists(arguments, "controller")) {
					arguments.controller = arguments.module & "." & arguments.controller;
					StructDelete(arguments, "module");
				}
			}
			
			// if we are using resources, use their names in the route name
			if (StructKeyExists(arguments, "resource")) {
				loc.name = ListAppend(loc.name, arguments.resource);
				if (arguments.$singular) {
					loc.entity = ListLast(loc.name);
					loc.name = REREplace(loc.name, "#loc.entity#$", singularize(loc.entity));
				}
			}
				
			// if we have a name, add it to arguments
			if (loc.name NEQ "")
				arguments.name = REReplace(loc.name, ",(\w)", "\U\1", "ALL");
			
			// put route arguments on structure
			// TODO: handle optional arguments
			ArrayAppend(variables.routes, arguments);
			addRoute(argumentCollection=arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="$get" returntype="struct" access="public" hint="Match a GET url">
		<cfargument name="name" type="string" required="false" />
		<cfreturn match(method="get", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="post" returntype="struct" access="public" hint="Match a POST url">
		<cfargument name="name" type="string" required="false" />
		<cfreturn match(method="post", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="put" returntype="struct" access="public" hint="Match a PUT url">
		<cfargument name="name" type="string" required="false" />
		<cfreturn match(method="put", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="delete" returntype="struct" access="public" hint="Match a DELETE url">
		<cfargument name="name" type="string" required="false" />
		<cfreturn match(method="delete", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="root" returntype="struct" access="public" hint="Match root directory">
		<cfargument name="to" type="string" required="false" />
		<cfreturn match(name="root", pattern="/", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="wildcard" returntype="struct" access="public" hint="Special wildcard matching">
		<cfscript>
			if (StructKeyExists(scopeStack[1], "controller")) {
				match(name="wildcard", pattern="/[action]/[key]");
				match(name="wildcard", pattern="/[action]");
				match(name="wildcard", pattern="/", action="index");
			} else {
				match(name="wildcard", pattern="/[controller]/[action]/[key]");
				match(name="wildcard", pattern="/[controller]/[action]");
				match(name="wildcard", pattern="/[controller]", action="index");
			}
			return this;
		</cfscript>
	</cffunction>
	
	<!-------------
	--- Scoping ---
	-------------->
	
	<cffunction name="scope" returntype="struct" access="public" hint="Set certain parameters for future calls">
		<cfargument name="path" type="string" required="false" />
		<cfargument name="module" type="string" required="false" />
		<cfargument name="resource" type="string" required="false" />
		<cfargument name="$call" type="string" default="scope" />
		<cfscript>
			
			// combine path with scope path
			if (StructKeyExists(scopeStack[1], "path") AND StructKeyExists(arguments, "path"))
				arguments.path = Replace(scopeStack[1].path & "/" & arguments.path, "//", "/", "ALL");
			
			// combine module with scope module
			if (StructKeyExists(scopeStack[1], "module") AND StructKeyExists(arguments, "module"))
				arguments.module = scopeStack[1].module & "." & arguments.module;
			
			// put scope arguments on the 
			StructAppend(arguments, scopeStack[1], false);
			ArrayPrepend(scopeStack, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="namespace" returntype="struct" access="public" hint="Set up namespace for future calls">
		<cfargument name="name" type="string" required="true" />
		<cfscript>
			return scope(path="/#hyphenize(arguments.name)#", module=arguments.name, $call="namespace");
		</cfscript>
	</cffunction>
	
	<!---------------
	--- Resources ---
	---------------->
	
	<cffunction name="resource" returntype="struct" access="public" hint="Set up REST singular resource">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="nested" type="boolean" default="false" />
		<cfargument name="$plural" type="boolean" default="false" />
		<cfargument name="$call" type="string" default="resource" />
		<cfscript>
			var loc = {};
			
			// determine entity name
			loc.entity = arguments.$plural ? singularize(arguments.name) : arguments.name;
			
			// if no controller is defined, assume the resource name
			if (NOT StructKeyExists(arguments, "controller"))
				arguments.controller = loc.entity;
				
			// set up mapping path 
			loc.path = "/" & hyphenize(arguments.name);
			loc.resource = arguments.name;
			
			// if we are already under a resource
			if (StructKeyExists(scopeStack[1], "resource")) {
				
				// figure out last resource name and append current resource
				loc.lastResource = singularize(ListLast(scopeStack[1].resource));
				loc.origResource = REReplace(scopeStack[1].resource, ListLast(scopeStack[1].resource) & "$", loc.lastResource);
				loc.resource = ListAppend(loc.origResource, loc.resource);
				
				// if dealing with a plural resource, include its key
				if (scopeStack[1].$call EQ "resources")
					loc.path = "/[" & loc.lastResource & "Key]" & loc.path;
			}
			
			// scope using the resource name as the path
			scope(path=loc.path, controller=arguments.controller, resource=loc.resource, $call=arguments.$call);
			
			// NOTE: see 'end()' to see the routing logic for resources
				
			// call end() automatically unless this is a nested call
			return arguments.nested ? this : end();
		</cfscript>
	</cffunction>
	
	<cffunction name="resources" returntype="struct" access="public" hint="Set up REST plural resource">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="nested" type="boolean" default="false" />
		<cfscript>
			return resource($plural=true, $call="resources", argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="member" returntype="struct" access="public" hint="Apply routes to resource member">
		<cfscript>
			return scope(path="[key]", $call="member");
		</cfscript>
	</cffunction>
	
	<cffunction name="collection" returntype="struct" access="public" hint="Apply routes to resource collection">
		<cfargument name="$call" type="string" default="collection" />
		<cfscript>
			StructAppend(arguments, scopeStack[1], false);
			ArrayPrepend(scopeStack, arguments);
			return this;
		</cfscript>
	</cffunction>
</cfcomponent>