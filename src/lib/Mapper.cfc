<cfcomponent output="false">
	<cfinclude template="#application.wheels.webPath#/wheels/global/functions.cfm" />
	
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
			// create plural resource routes
			if (scopeStack[1].$call EQ "resources") {
				collection();
					if (ListFind(scopeStack[1].actions, "index"))
						$get(pattern="", action="index");
					if (ListFindNoCase(scopeStack[1].actions, "create"))
						post(pattern="", action="create");
				end();
				if (ListFindNoCase(scopeStack[1].actions, "new")) {
					scope(path=scopeStack[1].collectionPath, $call="new");
						$get(pattern="new", action="new", name="new");
					end();
				}
				member();
					if (ListFind(scopeStack[1].actions, "edit"))
						$get(pattern="edit", action="edit", name="edit");
					if (ListFind(scopeStack[1].actions, "show"))
						$get(pattern="", action="show");
					if (ListFind(scopeStack[1].actions, "update"))
						put(pattern="", action="update");
					if (ListFind(scopeStack[1].actions, "delete"))
						delete(pattern="", action="delete");
				end();
				
			// create singular resource routes
			} else if (scopeStack[1].$call EQ "resource") {
				if (ListFind(scopeStack[1].actions, "create")) {
					collection();
						post(pattern="", action="create");
					end();
				}
				if (ListFind(scopeStack[1].actions, "new")) {
					scope(path=scopeStack[1].memberPath, $call="new");
						$get(pattern="new", action="new", name="new");
					end();
				}
				member();
					if (ListFind(scopeStack[1].actions, "edit"))
						$get(pattern="edit", action="edit", name="edit");
					if (ListFind(scopeStack[1].actions, "show"))
						$get(pattern="", action="show");
					if (ListFind(scopeStack[1].actions, "update"))
						put(pattern="", action="update");
					if (ListFind(scopeStack[1].actions, "delete"))
						delete(pattern="", action="delete");
				end();
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
		<cfargument name="name" type="string" required="false" hint="Name for route. Used for path helpers." />
		<cfargument name="pattern" type="string" required="false" hint="Pattern to match for route" />
		<cfargument name="to" type="string" required="false" hint="Set controller##action for route" />
		<cfargument name="methods" type="string" required="false" hint="HTTP verbs that match route" />
		<cfargument name="module" type="string" required="false" hint="Namespace to append to controller" />
		<cfscript>
			var loc = {};
			
			// use scoped controller if found
			if (StructKeyExists(scopeStack[1], "controller") AND NOT StructKeyExists(arguments, "controller"))
				arguments.controller = scopeStack[1].controller;
			
			// use scoped module if found
			if (StructKeyExists(scopeStack[1], "module")) {
				if (StructKeyExists(arguments, "module"))
					arguments.module &= "." & scopeStack[1].module;
				else
					arguments.module = scopeStack[1].module;
			}
			
			// interpret 'to' as 'controller#action'
			if (StructKeyExists(arguments, "to")) {
				arguments.controller = ListFirst(arguments.to, "##");
				arguments.action = ListLast(arguments.to, "##");
				StructDelete(arguments, "to");
			}
			
			// pull route name from arguments if it exists
			loc.name = "";
			if (StructKeyExists(arguments, "name")) {
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
			
			// remove 'methods' argument if settings disable it
			if (NOT variables.methods AND StructKeyExists(arguments, "methods"))
				StructDelete(arguments, "methods");
			
			// add scoped path to pattern
			if (StructKeyExists(scopeStack[1], "path"))
				arguments.pattern = scopeStack[1].path & "/" & arguments.pattern;
			
			// if both module and controller are set, combine them
			if (StructKeyExists(arguments, "module") AND StructKeyExists(arguments, "controller")) {
				arguments.controller = arguments.module & "." & arguments.controller;
				StructDelete(arguments, "module");
			}
			
			// build named routes in correct order according to rails conventions
			switch (scopeStack[1].$call) {
				case "resource":
				case "resources":
				case "collection":
					loc.nameStruct = [loc.name, $scopeName(), $collection()];
					break;
				case "member":
				case "new":
					loc.nameStruct = [loc.name, $scopeName(), $member()];
					break;
				default:
					loc.nameStruct = [$scopeName(), $collection(), loc.name];
			}
			
			// transform array into named route
			loc.name = ArrayToList(loc.nameStruct);
			loc.name = REReplace(loc.name, "^,+|,+$", "", "ALL");
			loc.name = REReplace(loc.name, ",+(\w)", "\U\1", "ALL");
			loc.name = REReplace(loc.name, ",", "", "ALL");
				
			// if we have a name, add it to arguments
			if (loc.name NEQ "")
				arguments.name = loc.name;
			
			// handle optional arguments
			if (arguments.pattern CONTAINS "(") {
				
				// confirm nesting of optional segments
				if (REFind("\).*\(", arguments.pattern))
					$throw(type="Wheels.InvalidRoute", message="Optional pattern segments must be nested.");
				
				// strip closing parens from pattern
				loc.pattern = Replace(arguments.pattern, ")", "", "ALL");
				
				// loop over all possible patterns
				while (loc.pattern NEQ "") {
					
					// add current route to wheels
					$addRoute(argumentCollection=arguments, pattern=Replace(loc.pattern, "(", "", "ALL"));
					
					// remove last optional segment
					loc.pattern = REReplace(loc.pattern, "(^|\()[^(]+$", "");
				}
				
			} else {
				
				// add route to wheels as is
				$addRoute(argumentCollection=arguments);
			}
			
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
		<cfargument name="action" default="index" hint="Default action for wildcard patterns" />
		<cfscript>
			if (StructKeyExists(scopeStack[1], "controller"))
				match(name="wildcard", pattern="[action](/[key])", action=arguments.action);
			else
				match(name="wildcard", pattern="[controller](/[action](/[key]))", action=arguments.action);
			return this;
		</cfscript>
	</cffunction>
	
	<!-------------
	--- Scoping ---
	-------------->
	
	<cffunction name="scope" returntype="struct" access="public" hint="Set certain parameters for future calls">
		<cfargument name="name" type="string" required="false" hint="Named route prefix" />
		<cfargument name="path" type="string" required="false" hint="Path prefix" />
		<cfargument name="module" type="string" required="false" hint="Namespace to append to controllers" />
		<cfargument name="controller" type="string" required="false" hint="Controller to use in routes" />
		<cfargument name="$call" type="string" default="scope" />
		<cfscript>
			
			// combine path with scope path
			if (StructKeyExists(scopeStack[1], "path") AND StructKeyExists(arguments, "path"))
				arguments.path = $normalizePath(scopeStack[1].path & "/" & arguments.path);
			
			// combine module with scope module
			if (StructKeyExists(scopeStack[1], "module") AND StructKeyExists(arguments, "module"))
				arguments.module = scopeStack[1].module & "." & arguments.module;
				
			// combine name with scope name
			if (StructKeyExists(arguments, "name") AND StructKeyExists(scopeStack[1], "name"))
				arguments.name = scopeStack[1].name & capitalize(arguments.name);
			
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
		<cfreturn scope(argumentCollection=arguments, $call="namespace") />
	</cffunction>
	
	<cffunction name="$controller" returntype="struct" access="public" hint="Set up controller for future calls">
		<cfargument name="controller" type="string" required="true" />
		<cfargument name="name" type="string" default="#arguments.controller#" />
		<cfargument name="path" type="string" default="#hyphenize(arguments.controller)#" />
		<cfreturn scope(argumentCollection=arguments, $call="controller") />
	</cffunction>
	
	<!---------------
	--- Resources ---
	---------------->
	
	<cffunction name="resource" returntype="struct" access="public" hint="Set up singular REST resource">
		<cfargument name="name" type="string" required="true" hint="Name of resource" />
		<cfargument name="nested" type="boolean" default="false" hint="Whether or not additional calls will be nested" />
		<cfargument name="controller" type="string" required="false" hint="Override controller used by resource" />
		<cfargument name="singular" type="string" required="false" hint="Override singularize() result in plural resources" />
		<cfargument name="plural" type="string" required="false" hint="Override pluralize() result in singular resource" />
		<cfargument name="only" type="string" default="" hint="List of REST routes to generate" />
		<cfargument name="except" type="string" default="" hint="List of REST routes not to generate, takes priority over only" />
		<cfargument name="$call" type="string" default="resource" />
		<cfargument name="$plural" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			loc.args = {};
			
			// turn name into a path
			loc.path = hyphenize(arguments.name);
			
			// if plural resource
			if (arguments.$plural) {
				
				// setup singular and plural words
				if (NOT StructKeyExists(arguments, "singular"))
					arguments.singular = singularize(arguments.name);
				arguments.plural = arguments.name;
				
				// set collection and scoped paths
				loc.args.collection = arguments.plural;
				loc.args.nestedPath = "#loc.path#/[#arguments.singular#Key]";
				loc.args.memberPath = "#loc.path#/[key]";
				
				// for uncountable plurals, append "Index"
				if (arguments.singular EQ arguments.plural)
					loc.args.collection &= "Index";
				
				// setup loc.args.actions
				loc.args.actions = "index,new,create,show,edit,update,delete";
				
			// if singular resource
			} else {
				
				// setup singular and plural words
				arguments.singular = arguments.name;
				if (NOT StructKeyExists(arguments, "plural"))
					arguments.plural = pluralize(arguments.name);
				
				// set collection and scoped paths
				loc.args.collection = arguments.singular;
				loc.args.memberPath = loc.path;
				loc.args.nestedPath = loc.path;
				
				// setup loc.args.actions
				loc.args.actions = "new,create,show,edit,update,delete";
			}
			
			// set member name
			loc.args.member = arguments.singular;
			
			// set collection path
			loc.args.collectionPath = loc.path;
			
			// consider only / except REST routes for resources
			// allow arguments.only to override loc.args.only
			if (ListLen(arguments.only) GT 0)
				loc.args.actions = LCase(arguments.only);
			
			// remove unwanted routes from loc.args.only
			if (ListLen(arguments.except) GT 0) {
				loc.except = ListToArray(arguments.except);
				loc.iEnd = ArrayLen(loc.except);
				for (loc.i=1; loc.i LTE loc.iEnd; loc.i++)
					loc.args.actions = REReplace(loc.args.actions, "\b#loc.except[loc.i]#\b(,?|$)", "");
			}
			
			// if controller name was passed, use it
			if (StructKeyExists(arguments, "controller")) {
				loc.args.controller = arguments.controller;
				
			} else {
				
				// set controller name based on naming preference
				switch (application.wheels.resourceControllerNaming) {
					case "name": loc.args.controller = arguments.name; break;
					case "singular": loc.args.controller = arguments.singular; break;
					default: loc.args.controller = arguments.plural;
				}
			}
			
			// if parent member found, use as scoped name
			if (StructKeyExists(scopeStack[1], "member"))
				loc.args.name = scopeStack[1].member;
				
			// use parent resource nested path if found
			if (StructKeyExists(scopeStack[1], "nestedPath"))
				loc.args.path = scopeStack[1].nestedPath;
			
			// scope the resource
			scope($call=arguments.$call, argumentCollection=loc.args);
				
			// call end() automatically unless this is a nested call
			// NOTE: see 'end()' source for the resource routes logic
			if (NOT arguments.nested)
				end();
				
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="resources" returntype="struct" access="public" hint="Set up REST plural resource">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="nested" type="boolean" default="false" />
		<cfreturn resource($plural=true, $call="resources", argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="member" returntype="struct" access="public" hint="Apply routes to resource member">
		<cfreturn scope(path=scopeStack[1].memberPath, $call="member") />
	</cffunction>
	
	<cffunction name="collection" returntype="struct" access="public" hint="Apply routes to resource collection">
		<cfreturn scope(path=scopeStack[1].collectionPath, $call="collection") />
	</cffunction>
	
	<!---------------------
	--- Private Methods ---
	---------------------->
	
	<cffunction name="$addRoute" returntype="void" access="private" hint="Add route to cfwheels, removing useless params">
		<cfscript>
					
			// remove controller and action if they are route variables
			if (Find("[controller]", arguments.pattern) AND StructKeyExists(arguments, "controller"))
				StructDelete(arguments, "controller");
			if (Find("[action]", arguments.pattern) AND StructKeyExists(arguments, "action"))
				StructDelete(arguments, "action");
				
			// add route to cfwheels with normalized path
			addRoute(argumentCollection=arguments, pattern=$normalizePath(arguments.pattern));
		</cfscript>
	</cffunction>
	
	<cffunction name="$normalizePath" returntype="string" access="private" hint="Force leading slashes, remove trailing and duplicate slashes">
		<cfargument name="path" type="string" required="true" />
		<cfreturn "/" & Replace(REReplace(arguments.path, "(^/+|/+$)", "", "ALL"), "//", "/", "ALL") />
	</cffunction>
	
	<cffunction name="$member" returntype="string" access="private" hint="Get member name if defined">
		<cfreturn iif(StructKeyExists(scopeStack[1], "member"), "scopeStack[1].member", DE("")) />
	</cffunction>
	
	<cffunction name="$collection" returntype="string" access="private" hint="Get collection name if defined">
		<cfreturn iif(StructKeyExists(scopeStack[1], "collection"), "scopeStack[1].collection", DE("")) />
	</cffunction>
	
	<cffunction name="$scopeName" returntype="string" access="private" hint="Get scoped route name if defined">
		<cfreturn iif(StructKeyExists(scopeStack[1], "name"), "scopeStack[1].name", DE("")) />
	</cffunction>
</cfcomponent>