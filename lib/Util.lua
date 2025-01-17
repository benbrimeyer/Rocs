local Util = {}

function Util.assign(toObj, ...)
	for _, fromObj in ipairs({...}) do
		for key, value in pairs(fromObj) do
			toObj[key] = value
		end
	end

	return toObj
end

function Util.runReducer(staticAggregate, values, defaultReducer)
	local reducedValue = (staticAggregate.reducer or defaultReducer)(values)

	if staticAggregate.check then
		assert(staticAggregate.check(reducedValue))
	end

	local data = reducedValue
	if staticAggregate.defaults and type(reducedValue) == "table" then
		data = setmetatable(reducedValue, {
			__index = staticAggregate.defaults
		})
	end

	if staticAggregate.check then
		assert(staticAggregate.check(data))
	end

	return data
end

function Util.makeToString(staticName)
	return function(self)
		return ("%s(%s)"):format(staticName, getmetatable(self).name)
	end
end

function Util.concat(list, ...)
	local args = { ... }
	local result = {}
	for i = 1, #list do
		result[i] = list[i]
	end
	for i = 1, #args do
		local value = args[i]
		for j = 1, #value do
			result[#result + 1] = value[j]
		end
	end
	return result
end

function Util.callCounter()
	return setmetatable({
		call = function(self, key)
			self[key] = self[key] + 1
		end
	}, {
		__index = function(self, key)
			self[key] = 0
			return 0
		end
	})
end

function Util.uniqueIdCounter(prefix)
	prefix = prefix or ""
	local count = 0

	return function ()
		count = count + 1
		return prefix .. count
	end
end

local function makeArrayEntityCheck(array)
	return function(instance)
		for _, className in ipairs(array) do
			if instance.ClassName == className then
				return true
			end
		end

		return
			false,
			("Instance type %q is not allowed to have this component!")
				:format(instance.ClassName)
	end
end
function Util.runEntityCheck(staticAggregate, instance)
	if staticAggregate.entityCheck == nil then
		return true
	end

	if type(staticAggregate.entityCheck) == "table" then
		staticAggregate.entityCheck = makeArrayEntityCheck(staticAggregate.entityCheck)
	end

	return staticAggregate.entityCheck(instance)
end

function Util.deepCopy(t)
	if type(t) == "table" then
		local n = {}
		for i,v in pairs(t) do
			n[i] = Util.deepCopy(v)
		end
		return n
	else
		return t
	end
end

function Util.deepEquals(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for k in pairs(a) do
		local av = a[k]
		local bv = b[k]
		if type(av) == "table" and type(bv) == "table" then
			local result = Util.deepEquals(av, bv)
			if not result then
				return false
			end
		elseif av ~= bv then
			return false
		end
	end

	-- extra keys in b
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end

	return true
end

function Util.requireAllInAnd(instance, callback, self)
	for _, object in ipairs(instance:GetChildren()) do
		if object:IsA("ModuleScript") then
			callback(self, require(object))
		else
			Util.requireAllInAnd(object, callback, self)
		end
	end
end

return Util
