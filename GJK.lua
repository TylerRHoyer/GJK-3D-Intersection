--Gilbert-Johnson-Keerthi distance and intersection tests
--Tyler R. Hoyer
--11/20/2014

--May return early if no intersection if found. If it is primed, it will run in amortized constant time (untested).

--If the distance function is used between colliding objects, the program
--may loop a hundred times without finding a result. If this is the case, 
--it will throw an error. The check is omited for speed. If the objects
--might intersect eachother, call the intersection method first.

--Objects must implement the :getFarthestPoint(dir) function which returns the
--farthest point in a given direction.

--Used Roblox's Vector3 userdata. Outside implementations will require a implementation of the methods of
--the Vector3's. :Dot, :Cross, .new, and .magnitude must be defined.

local abs = math.abs
local min = math.min
local huge = math.huge
local origin = Vector3.new()

local function loopRemoved(data, step)
	--We're on the next step
	step = step + 1
	
	--If we have completed the last cycle, stop
	if step > #data then
		return nil
	end
	
	--To be the combination without the value
	local copy = {}
	
	--Copy the data up to the missing value
	for i = 1, step - 1 do
		copy[i] = data[i]
	end
	
	--Copy the data on the other side of the missing value
	for i = step, #data - 1 do
		copy[i] = data[i + 1]
	end
	
	--return the step, combination, and missing value
	return step, copy, data[step]
end

--Finds the vector direction to search for the next point
--in the simplex. 
local function getDir(points, to)
	--Single point, return vector
	if #points == 1 then
		return to - points[1]
		
	--Line, return orthogonal line
	elseif #points == 2 then
		local v1 = points[2] - points[1]
		local v2 = to - points[1]
		return v1:Cross(v2):Cross(v1)
		
	--Triangle, return normal
	else
		local v1 = points[3] - points[1]
		local v2 = points[2] - points[1]
		local v3 = to - points[1]
		local n = v1:Cross(v2)
		return n:Dot(v3) < 0 and -n or n
	end
end

--The function that finds the intersection between two sets
--of points, s1 and s2. s1 and s2 must return the point in
--the set that is furthest in a given direction when called.
--If the start direction sV is specified as the seperation
--vector, the program runs in constant time. (excluding the
--user implemented functions for finding the furthest point).
function intersection(s1, s2, sV)
	local points = {}

	-- find point 
	local function support(dir)
		local a = s1(dir)
		local b = s2(-dir)
		points[#points + 1] = a - b
		return dir:Dot(a) < dir:Dot(b)
	end
	
	-- find all points forming a simplex
	if support(sV)
		or support(getDir(points, origin))
		or support(getDir(points, origin))
		or support(getDir(points, origin))
	then
		return false
	end

	local step, others, removed = 0
	repeat
		step, others, removed = loopRemoved(points, step)
		local dir = getDir(others, removed)
		if others[1]:Dot(dir) > 0 then
			points = others
			if support(-dir) then
				return false
			end
			step = 0
		end
	until step == 4
	
	return true
end

--Checks if two vectors are equal
local function equals(p1, p2)
	return p1.x == p2.x and p1.y == p2.y and p1.z == p2.z
end

--Gets the mathematical scalar t of the parametrc line defined by
--o + t * v of a point p on the line (the magnitude of the projection).
local function getT(o, v, p)
	return (p - o):Dot(v) / v:Dot(v)
end

--Returns the scalar of the closest point on a line to
--the origin. Note that if the vector is a zero vector then
--it treats it as a point offset instead of a line.
local function lineToOrigin(o, v)
	if equals(v, origin) then
		return o
	end
	local t = getT(o, v, origin)
	if t < 0 then 
		t = 0
	elseif t > 1 then 
		t = 1
	end
	return o + v*t
end

--Convoluted to deal with cases like points in the same place
local function closestPoint(a, b, c)
	--if abc is a line
	if c == nil then
		--get the scalar of the closest point
		local dir = b - a
		local t = getT(a, dir, origin)
		if t < 0 then t = 0
		elseif t > 1 then t = 1
		end
		--and return the point
		return a + dir * t
	end
	
	--Otherwise it is a triangle.
	--Define all the lines of the triangle and the normal
	local vAB, vBC, vCA = b - a, c - b, a - c
	local normal = vAB:Cross(vBC)
	
	--If two points are in the same place then
	if normal.magnitude == 0 then
		
		--Find the closest line between ab and bc to the origin (it cannot be ac)
		local ab = lineToOrigin(a, vAB)
		local bc = lineToOrigin(b, vBC)
		if ab.magnitude < bc.magnitude then
			return ab
		else
			return bc
		end
		
	--The following statements find the line which is closest to the origin
	--by using voroni regions. If it is inside the triangle, it returns the
	--normal of the triangle.
	elseif a:Dot(a + vAB * getT(a, vAB, c) - c) <= 0 then
		return lineToOrigin(a, vAB)
	elseif b:Dot(b + vBC * getT(b, vBC, a) - a) <= 0 then
		return lineToOrigin(b, vBC)
	elseif c:Dot(c + vCA * getT(c, vCA, b) - b) <= 0 then
		return lineToOrigin(c, vCA)
	else
		return -normal * getT(a, normal, origin)
	end
end

--The distance function. Works like the intersect function above. Returns
--the translation vector between the two closest points.
function distance(s1, s2, sV)
	local function support (dir)
		return s1(dir) - s2(-dir)
	end
	
	--Find the initial three points in the search direction, opposite of the
	--search direction, and in the orthoginal direction between those two 
	--points to the origin.
	local a = support(sV)
	local b = support(-a)
	local c = support(-closestPoint(a, b))
	
	--Setup maximum loops
	local i = 1
	while i < 100 do
		i = i + 1
		
		--Get the closest point on the triangle
		local p = closestPoint(a, b, c)
		
		--If it is the origin, the objects are just touching, 
		--return a zero vector.
		if equals(p, origin) then
			return origin
		end
		
		--Search in the direction from the closest point
		--to the origin for a point. 
		local dir = p.unit
		local d = support(dir)
		local dd = d:Dot(dir)
		local dm = math.min(
			a:Dot(dir),
			b:Dot(dir),
			c:Dot(dir)
		)
		
		--If the new point is farther or equal to the closest 
		--point on the triangle, then we have found the closest 
		--point.
		if dd >= dm then
			--return the point on the minkowski difference as the
			--translation vector between the two closest point.
			return -p
		end
		
		--Otherwise replace the point on the triangle furthest 
		--from the origin with the new point
		local ma, mb, mc = a:Dot(dir), b:Dot(dir), c:Dot(dir)
		if ma > mb then
			if ma > mc then
				a = d
			else
				c = d
			end
		elseif mb > mc then
			b = d
		else
			c = d
		end
	end
	
	--Return an error if no point was found in the maximum 
	--number of iterations
	error 'Unable to find distance, are they intersecting?'
end

return {
	intersection = intersection; 
	distance = distance;
}
