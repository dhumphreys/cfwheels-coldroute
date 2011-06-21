<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfscript>
			this.version = "1.2";
			application.wheels.coldRoute = CreateObject("component", "/plugins.coldroute.coldroute.ColdRoute").init();
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="draw" mixin="application" returntype="struct" access="public">
		<cfreturn application.wheels.coldRoute.draw() />
	</cffunction>
	
	<cffunction name="$loadRoutes" mixin="application" returntype="void" access="public" output="false">
		<cfscript>
			var loc = {};
			
			// clear out the route info
			ArrayClear(application.wheels.routes);
			StructClear(application.wheels.namedRoutePositions);
	
			// load developer routes first
			$include(template="#application.wheels.configPath#/routes.cfm");
			
			// build any routes call through the router
			// todo: just call addRoute() from ColdRoute.cfc
			loc.routes = application.wheels.coldRoute.routes();
			loc.iEnd = ArrayLen(loc.routes);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				addRoute(argumentCollection=loc.routes[loc.i]);
	
			// add the wheels default routes at the end if requested
			if (application.wheels.loadDefaultRoutes)
				addDefaultRoutes();
	
			// set lookup info for the named routes
			$setNamedRoutePositions();
		</cfscript>
	</cffunction>
</cfcomponent>