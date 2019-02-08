local Util = require(script.Parent.Util)

local DependencyStep = {}
DependencyStep.__index = DependencyStep

function DependencyStep.new(factory, qualifier, dependencies)
	return setmetatable({
		_factory = factory;
		_rocs = factory._rocs;
		_qualifier = qualifier;
		_dependencies = dependencies;
	}, DependencyStep)
end

function DependencyStep.combineDependencies(steps)
	local dependencies = {}

	for i, dependencyStep in ipairs(steps) do
		if dependencyStep._dependencies == true then
			return true -- "poison" chain removing instance optimization
		end

		dependencies[i] = dependencyStep._dependencies
	end

	return Util.concat(unpack(dependencies))
end

function DependencyStep:evaluate(...)
	return self._qualifier(...)
end

function DependencyStep:evaluateMap(...)
	local aggregateArray = self:evaluate(...)

	if aggregateArray == nil or #aggregateArray == 0 then
		return nil
	end

	local map = {}

	for _, aggregate in ipairs(aggregateArray) do
		map[getmetatable(aggregate).name] = aggregate
	end

	return map
end

local DependencyFactory = {}
DependencyFactory.__index = DependencyFactory

function DependencyFactory.new(rocs)
	return setmetatable({
		_rocs = rocs;
	}, DependencyFactory)
end

function DependencyFactory.isDependencyStep(value)
	return type(value) == "table" and getmetatable(value) == DependencyStep
end

function DependencyFactory:hasComponent(componentResolvable)
	return DependencyStep.new(
		self,
		function(instance)
			local staticComponentAggregate = self._rocs:_getStaticComponentAggregate(componentResolvable)

			return {self._rocs:_getComponentAggregate(instance, staticComponentAggregate)}
		end,
		{componentResolvable}
	)
end

function DependencyFactory:hasMetadata(metadata)
	return DependencyStep.new(
		self,
		function(instance)
			local aggregates = {}

			for _, aggregate in ipairs(self._rocs:_getAllComponentAggregates(instance)) do
				if aggregate:get(metadata) ~= nil then
					aggregates[#aggregates + 1] = aggregate
				end
			end

			return aggregates
		end,
		true
	)
end

function DependencyFactory:_resolveStep(step)
	if DependencyFactory.isDependencyStep(step) then
		return step
	elseif self._rocs:isMetadata(step) then
		return self:hasMetadata(step)
	elseif type(step) == "string" then
		return self:hasComponent(step)
	end

	error("Invalid dependency in sequence", 2)
end

function DependencyFactory:all(...)
	local steps = {...}
	return DependencyStep.new(
		self,
		function (instance)
			local components = {}

			for i, step in ipairs(steps) do
				step = self:_resolveStep(step)


				local stepComponents = step:evaluate(instance)

				if stepComponents == nil then
					return
				end

				components[i] = stepComponents
			end

			return Util.concat(unpack(components))
		end,
		DependencyStep.combineDependencies(steps)
	)
end

function DependencyFactory:any(...)
	local steps = {...}
	return DependencyStep.new(
		self,
		function (instance)
			local components = {}
			for _, step in ipairs(steps) do
				step = self:_resolveStep(step)

				local stepComponents = step:evaluate(instance)

				if stepComponents ~= nil then
					components[#components + 1] = stepComponents
				end
			end

			if #components == 0 then
				return
			end

			return Util.concat(unpack(components))
		end,
		DependencyStep.combineDependencies(steps)
	)
end

return DependencyFactory