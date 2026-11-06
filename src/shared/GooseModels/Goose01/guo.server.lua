local TweenService = game:GetService("TweenService")

local goose = script.Parent
local hitbox = goose:WaitForChild("Hitbox")

--------------------------------------------------
-- Goose01 效果
--
-- 果实碰到 Hitbox 后：
-- 1. 判断果实的 left 值和鹅化物的 IsLeft 是否同侧
-- 2. 每个果实对当前鹅化物只允许触发一次
-- 3. 果实售价 +10%
-- 4. 果实移动到 Goose01.lujing.Part
-- 5. 移动完成后恢复正常掉落
-- 6. 触发后改变果实的 left 值（左变右，右变左）
--------------------------------------------------

local PRICE_MULTIPLIER = 1.10
local MOVE_TIME = 0.6

-- 防止同一个果实因为多个身体部件同时触发。
local processingFruits = {}

--------------------------------------------------
-- 移动目标
--------------------------------------------------

local lujing = goose:WaitForChild("lujing")
local targetPart = lujing:WaitForChild("Part")

--------------------------------------------------
-- 获取果实 CFrame
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
-- 设置果实 CFrame
--------------------------------------------------

local function SetFruitCFrame(fruit, cframe)
	if not fruit or not fruit.Parent then
		return
	end

	if fruit:IsA("Model") then
		fruit:PivotTo(cframe)
	elseif fruit:IsA("BasePart") then
		fruit.CFrame = cframe
	end
end

--------------------------------------------------
-- 设置果实物理状态
--------------------------------------------------

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

--------------------------------------------------
-- 获取果实价格
--------------------------------------------------

local function GetFruitPrice(fruit)
	local jiage = fruit:FindFirstChild("jiage", true)

	if not jiage or not jiage:IsA("IntValue") then
		return nil
	end

	return jiage
end

--------------------------------------------------
-- 获取果实左右侧
-- 根据你提供的图片，Apple 模型下有一个名为 "left" 的 BoolValue
--------------------------------------------------

local function GetFruitLeftValue(fruit)
	local leftValue = fruit:FindFirstChild("left")

	-- 兼容可能嵌套在更深层级的情况，如果外面找不到，就递归找
	if not leftValue then
		leftValue = fruit:FindFirstChild("left", true)
	end

	if not leftValue or not leftValue:IsA("BoolValue") then
		return nil
	end

	return leftValue
end

--------------------------------------------------
-- 判断是不是果实
--------------------------------------------------

local function IsFruit(object)
	if not object then
		return false
	end

	local fruit

	if object:IsA("BasePart") then
		fruit = object:FindFirstAncestorOfClass("Model")

		-- 如果果实本身就是一个 BasePart。
		if not fruit then
			fruit = object
		end
	elseif object:IsA("Model") then
		fruit = object
	end

	if not fruit then
		return false
	end

	-- 有 jiage IntValue 才认为是果实。
	if not GetFruitPrice(fruit) then
		return false
	end

	-- 必须有 left 属性才认为是完整的果实
	if not GetFruitLeftValue(fruit) then
		return false
	end

	return true, fruit
end

--------------------------------------------------
-- 移动果实到 lujing.Part
--------------------------------------------------

local function MoveFruitToPath(fruit)
	if not fruit or not fruit.Parent then
		return false
	end

	if not targetPart or not targetPart.Parent then
		return false
	end

	local startCFrame = GetFruitCFrame(fruit)

	if not startCFrame then
		return false
	end

	--------------------------------------------------
	-- 目标位置就是 lujing.Part。
	-- 保留果实原本的旋转。
	--------------------------------------------------

	local targetCFrame =
		CFrame.new(targetPart.Position)
		* (startCFrame - startCFrame.Position)

	--------------------------------------------------
	-- Tween 过程中固定果实，
	-- 避免物理系统影响移动。
	--------------------------------------------------

	SetFruitAnchored(fruit, true)

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection =
		cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			if fruit and fruit.Parent then
				SetFruitCFrame(fruit, cframeValue.Value)
			end
		end)

	local tween =
		TweenService:Create(
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

	--------------------------------------------------
	-- 移动完成后恢复正常掉落。
	--------------------------------------------------

	if fruit and fruit.Parent then
		SetFruitAnchored(fruit, false)
	end

	return true
end

--------------------------------------------------
-- 记录已经触发过当前鹅化物效果的果实
--
-- 使用弱键表：果实被销毁时自动清理，不会内存泄漏。
-- 每个鹅化物脚本都有自己的 triggeredFruits，
-- 所以 Goose01 和 Goose02 互不影响。
--------------------------------------------------

local triggeredFruits = setmetatable({}, { __mode = "k" })

--------------------------------------------------
-- 处理果实
--------------------------------------------------

local function ProcessFruit(fruit)
	if not fruit or not fruit.Parent then
		return
	end

	--------------------------------------------------
	-- 如果这个果实已经触发过当前鹅化物，直接返回
	--------------------------------------------------

	if triggeredFruits[fruit] then
		return
	end

	--------------------------------------------------
	-- 判断左右侧是否匹配
	--------------------------------------------------

	-- 1. 获取鹅化物在哪一侧 (来自 GooseServer 设置的 IsLeft 属性)
	local gooseIsLeft = goose:GetAttribute("IsLeft")

	-- 如果服务器没有设置这个属性（可能是旧版本），默认按鹅化物名字来推算或直接跳过
	if gooseIsLeft == nil then
		-- 兼容：如果没有 IsLeft 属性，但提供了 Side 属性
		local side = goose:GetAttribute("Side")
		gooseIsLeft = (side == "Left")
	end

	-- 2. 获取果实当前在哪一侧
	local fruitLeftValue = GetFruitLeftValue(fruit)
	if not fruitLeftValue then
		return
	end

	local fruitIsLeft = fruitLeftValue.Value

	-- 3. 同侧判断：鹅化物在左且果实在左，或者鹅化物在右且果实在右，才触发
	if gooseIsLeft ~= fruitIsLeft then
		return
	end

	-- 立刻标记，防止同一帧多个碰撞体同时触发
	triggeredFruits[fruit] = true

	--------------------------------------------------
	-- 价格 +10%
	--------------------------------------------------

	local jiage = GetFruitPrice(fruit)

	if jiage then
		jiage.Value =
			math.floor(
				jiage.Value * PRICE_MULTIPLIER
			)
	end

	fruit:SetAttribute(
		"LastGoose",
		goose:GetAttribute("GooseId")
			or goose.Name
	)

	--------------------------------------------------
	-- 改变果实的侧 (左变右，右变左)
	-- 这样之后果实就能触发另一侧的鹅化物了
	--------------------------------------------------

	fruitLeftValue.Value = not fruitLeftValue.Value

	print("[Goose01] 果实触发成功，当前果实侧改变为:", fruitLeftValue.Value and "Left" or "Right")

	--------------------------------------------------
	-- 移动到 lujing.Part
	--------------------------------------------------

	MoveFruitToPath(fruit)
end

--------------------------------------------------
-- Hitbox
--------------------------------------------------

hitbox.CanCollide = false
hitbox.CanTouch = true

hitbox.Touched:Connect(function(hit)
	local isFruit, fruit = IsFruit(hit)

	if not isFruit then
		return
	end

	ProcessFruit(fruit)
end)