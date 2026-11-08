local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitService = {}

--------------------------------------------------
-- 配置
--------------------------------------------------

local FruitFolder = ReplicatedStorage:WaitForChild("guoshi")

-- 果实经过每个出口点的时间
local MOVE_TIME = 0.5

-- 从 3 号位置移动出去以后，
-- 给它一个向下的初速度
local DROP_VELOCITY = Vector3.new(0, -3, 0)

--------------------------------------------------
-- 获取模型的主部件
--------------------------------------------------

local function GetPrimaryPart(model)

	if model:IsA("BasePart") then
		return model
	end

	if model:IsA("Model") then

		if model.PrimaryPart then
			return model.PrimaryPart
		end

		local primary = model:FindFirstChildWhichIsA("BasePart", true)

		if primary then
			model.PrimaryPart = primary
			return primary
		end
	end

	return nil
end

--------------------------------------------------
-- 设置果实位置
--------------------------------------------------

local function SetFruitCFrame(fruit, cframe)

	if fruit:IsA("Model") then
		fruit:PivotTo(cframe)

	elseif fruit:IsA("BasePart") then
		fruit.CFrame = cframe
	end
end

--------------------------------------------------
-- 获取果实位置
--------------------------------------------------

local function GetFruitCFrame(fruit)

	if fruit:IsA("Model") then
		return fruit:GetPivot()

	elseif fruit:IsA("BasePart") then
		return fruit.CFrame
	end

	return nil
end

--------------------------------------------------
-- 移动果实
--------------------------------------------------

local function MoveFruit(fruit, targetCFrame)

	if not fruit or not fruit.Parent then
		return false
	end

	local primaryPart = GetPrimaryPart(fruit)

	if not primaryPart then
		return false
	end

	local startCFrame = GetFruitCFrame(fruit)

	if not startCFrame then
		return false
	end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection

	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()

		if fruit and fruit.Parent then
			SetFruitCFrame(fruit, cframeValue.Value)
		end

	end)

	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(
			MOVE_TIME,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut
		),
		{
			Value = targetCFrame
		}
	)

	tween:Play()
	tween.Completed:Wait()

	if connection then
		connection:Disconnect()
	end

	cframeValue:Destroy()

	return true
end

--------------------------------------------------
-- 让果实掉落
--------------------------------------------------

local function DropFruit(fruit)

	if not fruit or not fruit.Parent then
		return
	end

	--------------------------------------------------
	-- Model
	--------------------------------------------------

	if fruit:IsA("Model") then

		local primaryPart = GetPrimaryPart(fruit)

		if not primaryPart then
			return
		end

		-- 让果实开始受到物理影响
		for _, obj in ipairs(fruit:GetDescendants()) do

			if obj:IsA("BasePart") then
				obj.Anchored = false
				obj.CanCollide = false
			end

		end

		primaryPart.AssemblyLinearVelocity = DROP_VELOCITY

		--------------------------------------------------
		-- Part
		--------------------------------------------------

	elseif fruit:IsA("BasePart") then

		fruit.Anchored = false
		fruit.CanCollide = false

		fruit.AssemblyLinearVelocity = DROP_VELOCITY

	end
end

--------------------------------------------------
-- 生成一个果实
--------------------------------------------------

function FruitService:SpawnFruit(player, plant)

	if not player then
		return nil
	end

	if not plant or not plant.Parent then
		return nil
	end

	--------------------------------------------------
	-- 找植物的 chuchang
	--------------------------------------------------

	local chuchang = plant:FindFirstChild("chuchang")

	if not chuchang then

		warn(
			"[FruitService] 找不到 chuchang:",
			plant:GetFullName()
		)

		return nil
	end

	--------------------------------------------------
	-- 找 1 / 2 / 3
	--------------------------------------------------

	local point1 = chuchang:FindFirstChild("1")
	local point2 = chuchang:FindFirstChild("2")
	local point3 = chuchang:FindFirstChild("3")

	if not point1 or not point2 or not point3 then

		warn(
			"[FruitService] chuchang 缺少 1 / 2 / 3"
		)

		return nil
	end

	--------------------------------------------------
	-- 根据植物当前 Fruit 决定生成什么果实
	--------------------------------------------------

	local fruitName = "Apple"

	local plantFruit = plant:GetAttribute("Fruit")

	if plantFruit and plantFruit ~= "" then
		fruitName = plantFruit
	end

	local fruitTemplate = FruitFolder:FindFirstChild(fruitName)

	if not fruitTemplate then

		warn(
			"[FruitService] 找不到果实:",
			fruitName
		)

		return nil
	end

	--------------------------------------------------
	-- 克隆果实
	--------------------------------------------------

	local fruit = fruitTemplate:Clone()

	fruit.Name = fruitName

	--------------------------------------------------
	-- 保存所属玩家
	--------------------------------------------------

	fruit:SetAttribute("OwnerUserId", player.UserId)

	--------------------------------------------------
	-- 保存果实类型
	--------------------------------------------------

	fruit:SetAttribute("FruitType", fruitName)

	--------------------------------------------------
	-- 读取价格
	--------------------------------------------------

	local jiage = fruit:FindFirstChild("jiage", true)

	if jiage and jiage:IsA("IntValue") then

		fruit:SetAttribute("Price", jiage.Value)

	else

		warn(
			"[FruitService] 果实没有 jiage:",
			fruit:GetFullName()
		)

	end

	--------------------------------------------------
	-- 放到植物里面
	--------------------------------------------------

	fruit.Parent = plant
	
	task.delay(45, function()
		if fruit and fruit.Parent then
			fruit:Destroy()
		end
	end)

	--------------------------------------------------
	-- 一开始固定在 1
	--------------------------------------------------

	if fruit:IsA("Model") then

		local primaryPart = GetPrimaryPart(fruit)

		if not primaryPart then

			warn(
				"[FruitService] 果实没有 BasePart:",
				fruit:GetFullName()
			)

			fruit:Destroy()
			return nil
		end

		for _, obj in ipairs(fruit:GetDescendants()) do

			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
			end

		end

		SetFruitCFrame(
			fruit,
			point1.CFrame
		)

	elseif fruit:IsA("BasePart") then

		fruit.Anchored = true
		fruit.CanCollide = false

		fruit.CFrame = point1.CFrame

	end

	--------------------------------------------------
	-- 1 → 2
	--------------------------------------------------

	local success = MoveFruit(
		fruit,
		point2.CFrame
	)

	if not success then
		return fruit
	end

	--------------------------------------------------
	-- 2 → 3
	--------------------------------------------------

	success = MoveFruit(
		fruit,
		point3.CFrame
	)

	if not success then
		return fruit
	end

	--------------------------------------------------
	-- 到达 3
	--------------------------------------------------

	DropFruit(fruit)
	
	task.delay(30, function()
		if fruit and fruit.Parent then
			fruit:Destroy()
		end
	end)

	return fruit
end

return FruitService
