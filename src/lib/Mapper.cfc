<cfcomponent output="false">
	<cfinclude template="../../../wheels/global/functions.cfm" />
	
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
					scope($call="new");
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
					scope($call="new");
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
		<cfargument name="name" type="string" required="false" />
		<cfargument name="pattern" type="string" required="false" />
		<cfargument name="to" type="string" required="false" />
		<cfargument name="methods" type="string" required="false" />
		<cfargument name="module" type="string" required="false" />
		<cfscript>
			var loc = {};
			
			// named route variables (initially empty)
			loc.scopeName = "";
			loc.memberName = "";
			loc.collectionName = "";
			loc.name = "";
			
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
			
			// pull name from arguments if it exists
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
			
			// force leading slashes, remove trailing and duplicate slashes
			arguments.pattern = Replace(arguments.pattern, "//", "/", "ALL");
			arguments.pattern = REReplace(arguments.pattern, "^([^/]+)", "/\1");
			arguments.pattern = REReplace(arguments.pattern, "([^/]+)/$", "\1");
			
			// if both module and controller are set, combine them
			if (StructKeyExists(arguments, "module") AND StructKeyExists(arguments, "controller")) {
				arguments.controller = arguments.module & "." & arguments.controller;
				StructDelete(arguments, "module");
			}
			
			// if we are using resources, use their names in the route name
			if (StructKeyExists(scopeStack[1], "collection"))
				loc.collectionName = scopeStack[1].collection;
			if (StructKeyExists(scopeStack[1], "member"))
				loc.memberName = scopeStack[1].member;
			
			// use scoped name if it is set
			if (StructKeyExists(scopeStack[1], "name"))
				loc.scopeName = scopeStack[1].name;
			
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
			
			// handle optional arguments
			if (arguments.pattern CONTAINS "(") {
				
				// confirm nesting of optional segments
				if (REFind("\).*\(", arguments.pattern))
					$throw(type="Wheels.InvalidRoute", message="Optional pattern segments must be nested.");
				
				// strip closing parens from pattern
				loc.pattern = Replace(arguments.pattern, ")", "", "ALL");
				
				// loop over all possible patterns
				while (loc.pattern NEQ "") {
					
					// duplicate arguments to avoid scoping problems
					loc.args = Duplicate(arguments);
					
					// remove action argument if [action] is a route variable
					if (Find("[action]", loc.pattern))
						StructDelete(loc.args, "action");
					
					// add current route to wheels
					loc.args.pattern = Replace(loc.pattern, "(", "", "ALL");
					addRoute(argumentCollection=Duplicate(arguments));
					
					// remove last optional segment
					loc.pattern = REReplace(loc.pattern, "(^|\()[^(]+$", "");
				}
				
			} else {
				
				// add route to wheels as is
				addRoute(argumentCollection=arguments);
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
		<cfargument name="name" type="string" required="false" />
		<cfargument name="path" type="string" required="false" />
		<cfargument name="module" type="string" required="false" />
		<cfargument name="$call" type="string" default="scope" />
		<cfscript>
			
			// combine path with scope path
			if (StructKeyExists(scopeStack[1], "path") AND StructKeyExists(arguments, "path"))
				arguments.path = Replace(scopeStack[1].path & "/" & arguments.path, "//", "/", "ALL");
			
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
	
	<cffunction name="resource" returntype="struct" access="public" hint="Set up singular REST resource">
		<cfargument name="name" type="string" required="true" hint="Name of resource" />
		<cfargument name="nested" type="boolean" default="false" hint="Whether or not additional calls will be nested" />
		<cfargument name="controller" type="string" required="false" hint="Override controller used by resource" />
		<cfargument name="singular" type="string" required="false" hint="Override singularize() result in plural resources" />
		<cfargument name="plural" type="string" required="false" hint="Override pluralize() result in singular resource" />
		<cfargument name="$call" type="string" default="resource" />
		<cfargument name="$plural" type="boolean" default="false" />
		<cfargument name="only" type="string" default="" hint="Use to specify REST routes to be generated" />
		<cfargument name="except" type="string" default="" hint="Use to specify REST routes to NOT be generated, takes priority over only" />
		<cfscript>
			var loc = {};
			loc.args = {};
			
			// if plural resource
			if (arguments.$plural) {
				
				// setup singular and plural words
				if (NOT StructKeyExists(arguments, "singular"))
					arguments.singular = singularize(arguments.name);
				arguments.plural = arguments.name;
				
				// set collection, member path, and nested path
				loc.args.collection = arguments.plural;
				loc.args.nestedPath = "[#arguments.singular#Key]";
				loc.args.memberPath = "[key]";
				
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
				
				// set collection and member path
				loc.args.collection = arguments.singular;
				loc.args.memberPath = "";
				
				// setup loc.args.actions
				loc.args.actions = "new,create,show,edit,update,delete";
			}
			
			// set member name
			loc.args.member = arguments.singular;
			
			// consider only / except REST routes for resources
			// allow arguments.only to override loc.args.only
			if (ListLen(arguments.only) GT 0)
				loc.args.actions = LCase(arguments.only);
			
			// remove unwanted routes from loc.args.only
			if (ListLen(arguments.except) GT 0) {
				loc.except = ListToArray(arguments.except);
				loc.iEnd = ArrayLen(loc.except);
				for (loc.i=1; loc.i LTE loc.iEnd; loc.i++)
					loc.args.actions = ReReplace(loc.args.actions, "\b#loc.except[loc.i]#\b(,?|$)", "");
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
			
			// prepend to member and collection if member is scoped
			if (StructKeyExists(scopeStack[1], "member")) {
				loc.args.member = scopeStack[1].member & capitalize(loc.args.member);
				loc.args.collection = scopeStack[1].member & capitalize(loc.args.collection);
			}
				
			// set mapping path, prepending nested path if scoped
			loc.args.path = hyphenize(arguments.name);
			if (StructKeyExists(scopeStack[1], "nestedPath"))
				loc.args.path = scopeStack[1].nestedPath & "/" & loc.args.path;
			
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
		<cfscript>
			return resource($plural=true, $call="resources", argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="member" returntype="struct" access="public" hint="Apply routes to resource member">
		<cfscript>
			return scope(path=scopeStack[1].memberPath, $call="member");
		</cfscript>
	</cffunction>
	
	<cffunction name="collection" returntype="struct" access="public" hint="Apply routes to resource collection">
		<cfscript>
			return scope($call="collection");
		</cfscript>
	</cffunction>
</cfcomponent>