local TweenService = game:GetService("TweenService")

local goose = script.Parent
local hitbox = goose:WaitForChild("Hitbox")

--------------------------------------------------
-- Goose13 效果
-- 果实售价 +20%
--------------------------------------------------

local PRICE_MULTIPLIER = 1.60
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

	--------------------------------------------------
	-- 价格 +20%
	--------------------------------------------------

	local jiage = GetFruitPrice(fruit)
	if jiage then
		jiage.Value = math.floor(jiage.Value * PRICE_MULTIPLIER)
	end

	fruit:SetAttribute(
		"LastGoose",
		goose:GetAttribute("GooseId") or goose.Name
	)

	fruitLeftValue.Value = not fruitLeftValue.Value

	print("[Goose05] 果实触发，价格 +20%")

	MoveFruitToPath(fruit)
end

hitbox.CanCollide = false
hitbox.CanTouch = true

hitbox.Touched:Connect(function(hit)
	local isFruit, fruit = IsFruit(hit)
	if not isFruit then return end
	ProcessFruit(fruit)
end)
