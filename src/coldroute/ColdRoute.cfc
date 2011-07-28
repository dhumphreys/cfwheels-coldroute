<cfcomponent output="false">
	<cfinclude template="/wheels/global/functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="restful" type="boolean" default="true" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#arguments.restful#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfscript>
			
			// set up control variables
			variables.scopeStack = ArrayNew(1);
			variables.restful = arguments.restful;
			variables.methods = arguments.restful OR arguments.methods;
			
			// fix naming collision with cfwheels get() and controller() methods
			this.get = variables.$get;
			this.controller = variables.$controller;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="draw" returntype="struct" access="public">
		<cfargument name="restful" type="boolean" default="#variables.restful#" hint="Pass 'true' to enable RESTful routes" />
		<cfargument name="methods" type="boolean" default="#variables.methods#" hint="Pass 'true' to enable routes distinguished by HTTP method" />
		<cfscript>
			variables.restful = arguments.restful;
			variables.methods = arguments.restful OR arguments.methods;
			
			// start with clean scope stack
			// TODO: resolve any race conditions
			variables.scopeStack = ArrayNew(1);
			ArrayPrepend(scopeStack, StructNew());
			variables.scopeStack[1].$call = "draw";
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="end" returntype="struct" access="public">
		<cfscript>
			
			// if last action was a resource, set up REST routes
			// TODO: consider non-restful routes
			if (scopeStack[1].$call EQ "resources") {
				collection();
					$get(pattern="", action="index");
					post(pattern="", action="create");
				end();
				scope($call="new");
					$get(pattern="new", action="new", name="new");
				end();
				member();
					$get(pattern="edit", action="edit", name="edit");
					$get(pattern="", action="show");
					put(pattern="", action="update");
					delete(pattern="", action="delete");
				end();
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
	
	<!---------------------
	--- Simple Matching ---
	---------------------->
	
	<cffunction name="match" returntype="struct" access="public" hint="Match a url">
		<cfargument name="name" type="string" required="false" />
		<cfargument name="pattern" type="string" required="false" />
		<cfargument name="to" type="string" required="false" />
		<cfargument name="methods" type="string" required="false" />
		<cfargument name="module" type="string" required="false" />
		<cfscript>
			var loc = {};
			
			// pull arguments from scope stack
			StructAppend(arguments, scopeStack[1], false);
			
			// named route variables (initially empty)
			loc.scopeName = "";
			loc.memberName = "";
			loc.collectionName = "";
			loc.name = "";
			
			// get control variables
			loc.hasScopeName = StructKeyExists(arguments, "scopeName");
			loc.hasModule = StructKeyExists(arguments, "module");
			loc.hasResource = StructKeyExists(arguments, "resource");
			
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
			if (loc.hasModule) {
				
				// append to controller or leave module variable set
				if (StructKeyExists(arguments, "controller")) {
					arguments.controller = arguments.module & "." & arguments.controller;
					StructDelete(arguments, "module");
				}
			}
			
			// if we are using resources, use their names in the route name
			if (loc.hasResource) {
				loc.collectionName = arguments.collection;
				loc.memberName = arguments.member;
			}
			
			// use scoped name if it is set
			if (loc.hasScopeName)
				loc.scopeName = arguments.scopeName;
			
			// build named routes in correct order according to rails conventions
			switch (scopeStack[1].$call) {
				case "resource":
				case "resources":
				case "collection":
					loc.nameStruct = [loc.name, loc.scopeName, loc.collectionName];
					break;
				case "member":
				case "new":
					loc.nameStruct = [loc.name, loc.scopeName, loc.memberName];
					break;
				default:
					loc.nameStruct = [loc.scopeName, loc.collectionName, loc.name];
			}
			
			// transform array into named route
			loc.name = ArrayToList(loc.nameStruct);
			loc.name = REReplace(loc.name, "^,+|,+$", "", "ALL");
			loc.name = REReplace(loc.name, ",+(\w)", "\U\1", "ALL");
			loc.name = REReplace(loc.name, ",", "", "ALL");
				
			// if we have a name, add it to arguments
			if (loc.name NEQ "")
				arguments.name = loc.name;
			
			// TODO: handle optional arguments
			// add routes to wheels
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
		<cfargument name="name" type="string" required="false" />
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
				
			// append to scoped name
			if (StructKeyExists(arguments, "name")) {
				if (StructKeyExists(scopeStack[1], "scopeName"))
					arguments.scopeName = scopeStack[1].scopeName & capitalize(arguments.name);
				else
					arguments.scopeName = arguments.name;
				StructDelete(arguments, "name");
			}
			
			// put scope arguments on the stack
			StructAppend(arguments, scopeStack[1], false);
			ArrayPrepend(scopeStack, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="namespace" returntype="struct" access="public" hint="Set up namespace for future calls">
		<cfargument name="module" type="string" required="true" />
		<cfargument name="name" type="string" default="#arguments.module#" />
		<cfargument name="path" type="string" default="#hyphenize(arguments.module)#" />
		<cfscript>
			return scope(argumentCollection=arguments, $call="namespace");
		</cfscript>
	</cffunction>
	
	<cffunction name="$controller" returntype="struct" access="public" hint="Set up controller for future calls">
		<cfargument name="controller" type="string" required="true" />
		<cfargument name="name" type="string" default="#arguments.controller#" />
		<cfargument name="path" type="string" default="#hyphenize(arguments.controller)#" />
		<cfscript>
			return scope(argumentCollection=arguments, $call="controller");
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
		<cfargument name="member" type="string" default="#singularize(arguments.name)#" />
		<cfargument name="collection" type="string" default="#arguments.name#" />
		<cfargument name="controller" type="string" default="#arguments.member#" />
		<cfscript>
			var loc = {};
			loc.nested = arguments.nested;
				
			// set up mapping path 
			arguments.path = hyphenize(arguments.name);
			arguments.resource = arguments.member;
			
			// if we are already under a resource, prepend proper parent member names
			if (StructKeyExists(scopeStack[1], "resource")) {
				arguments.member = scopeStack[1].member & capitalize(arguments.member);
				arguments.collection = scopeStack[1].member & capitalize(arguments.collection);
				
				// if dealing with a plural parent resource, include its key in the path
				if (scopeStack[1].$call EQ "resources")
					arguments.path = "[#scopeStack[1].resource#Key]/#arguments.path#";
			}
			
			// scope using the resource name as the path
			StructDelete(arguments, "name");
			StructDelete(arguments, "nested");
			StructDelete(arguments, "$plural");
			scope(argumentCollection=arguments);
				
			// call end() automatically unless this is a nested call
			// NOTE: see 'end()' source for the resource routes logic
			if (NOT loc.nested)
				end();
				
			return this;
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
		<cfscript>
			return scope($call="collection");
		</cfscript>
	</cffunction>
</cfcomponent>