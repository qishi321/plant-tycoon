local TweenService = game:GetService("TweenService")

local goose = script.Parent
local hitbox = goose:WaitForChild("Hitbox")

--------------------------------------------------
-- Goose03 效果
-- 果实售价不变，额外生成 1 个果实
--------------------------------------------------

local EXTRA_FRUIT_COUNT = 1
local MOVE_TIME = 0.6

local processingFruits = {}

local lujing = goose:WaitForChild("lujing")
local targetPart = lujing:WaitForChild("Part")

local function GetFruitCFrame(fruit)
	if fruit:IsA("Model") then
		return fruit:GetPivot()
	elseif fruit:IsA("BasePart") then
		return fruit.CFrame
	end
	return nil
end

local function SetFruitCFrame(fruit, cframe)
	if not fruit or not fruit.Parent then return end
	if fruit:IsA("Model") then
		fruit:PivotTo(cframe)
	elseif fruit:IsA("BasePart") then
		fruit.CFrame = cframe
	end
end

local function SetFruitAnchored(fruit, anchored)
	if fruit:IsA("Model") then
		for _, object in ipairs(fruit:GetDescendants()) do
			if object:IsA("BasePart") then
				object.Anchored = anchored
				object.CanCollide = false
			end
		end
	elseif fruit:IsA("BasePart") then
		fruit.Anchored = anchored
		fruit.CanCollide = false
	end
end

local function GetFruitPrice(fruit)
	local jiage = fruit:FindFirstChild("jiage", true)
	if not jiage or not jiage:IsA("IntValue") then return nil end
	return jiage
end

local function GetFruitLeftValue(fruit)
	local leftValue = fruit:FindFirstChild("left")
	if not leftValue then
		leftValue = fruit:FindFirstChild("left", true)
	end
	if not leftValue or not leftValue:IsA("BoolValue") then return nil end
	return leftValue
end

local function IsFruit(object)
	if not object then return false end
	local fruit
	if object:IsA("BasePart") then
		fruit = object:FindFirstAncestorOfClass("Model")
		if not fruit then fruit = object end
	elseif object:IsA("Model") then
		fruit = object
	end
	if not fruit then return false end
	if not GetFruitPrice(fruit) then return false end
	if not GetFruitLeftValue(fruit) then return false end
	return true, fruit
end

local function MoveFruitToPath(fruit)
	if not fruit or not fruit.Parent then return false end
	if not targetPart or not targetPart.Parent then return false end

	local startCFrame = GetFruitCFrame(fruit)
	if not startCFrame then return false end

	local targetCFrame =
		CFrame.new(targetPart.Position)
		* (startCFrame - startCFrame.Position)

	SetFruitAnchored(fruit, true)

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection =
		cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			if fruit and fruit.Parent then
				SetFruitCFrame(fruit, cframeValue.Value)
			end
		end)

	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(MOVE_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{ Value = targetCFrame }
	)

	tween:Play()
	tween.Completed:Wait()

	if connection then connection:Disconnect() end
	cframeValue:Destroy()

	if fruit and fruit.Parent then
		SetFruitAnchored(fruit, false)
	end

	return true
end

local triggeredFruits = setmetatable({}, { __mode = "k" })

--------------------------------------------------
-- 生成额外果实
--------------------------------------------------

local function SpawnExtraFruits(fruit, count)
	local fruitParent = fruit.Parent
	if not fruitParent then return end

	local baseCFrame = GetFruitCFrame(fruit)
	if not baseCFrame then return end

	for i = 1, count do
		local newFruit = fruit:Clone()

		-- 标记新果实已触发当前鹅化物，避免立即再次触发
		triggeredFruits[newFruit] = true

		local offset = CFrame.new(
			math.random(-20, 20) / 10,
			1 + i * 0.3,
			math.random(-20, 20) / 10
		)

		if newFruit:IsA("Model") then
			newFruit:PivotTo(baseCFrame * offset)
		elseif newFruit:IsA("BasePart") then
			newFruit.CFrame = baseCFrame * offset
		end

		SetFruitAnchored(newFruit, false)
		newFruit.Parent = fruitParent
	end
end

--------------------------------------------------
-- 处理果实
--------------------------------------------------

local function ProcessFruit(fruit)
	if not fruit or not fruit.Parent then return end
	if triggeredFruits[fruit] then return end

	local gooseIsLeft = goose:GetAttribute("IsLeft")
	if gooseIsLeft == nil then
		local side = goose:GetAttribute("Side")
		gooseIsLeft = (side == "Left")
	end

	local fruitLeftValue = GetFruitLeftValue(fruit)
	if not fruitLeftValue then return end

	if gooseIsLeft ~= fruitLeftValue.Value then return end

	triggeredFruits[fruit] = true

	fruit:SetAttribute(
		"LastGoose",
		goose:GetAttribute("GooseId") or goose.Name
	)

	--------------------------------------------------
	-- 生成额外果实
	--------------------------------------------------

	SpawnExtraFruits(fruit, EXTRA_FRUIT_COUNT)

	--------------------------------------------------
	-- 改变果实的侧
	--------------------------------------------------

	fruitLeftValue.Value = not fruitLeftValue.Value

	print("[Goose03] 果实触发，额外生成 " .. EXTRA_FRUIT_COUNT .. " 个果实")

	MoveFruitToPath(fruit)
end

hitbox.CanCollide = false
hitbox.CanTouch = true

hitbox.Touched:Connect(function(hit)
	local isFruit, fruit = IsFruit(hit)
	if not isFruit then return end
	ProcessFruit(fruit)
end)
