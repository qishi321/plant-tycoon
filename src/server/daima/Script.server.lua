--==================================================
-- FruitDropHandler.server.lua
-- 果实掉落 + 滑道效果
--==================================================

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local SLIDE_TAG = "FruitSlide"       -- 滑道标签
local SLIDE_SPEED = 25               -- 滑行速度 studs/s
local MOVE_TO_START_TIME = 0.1       -- 从当前位置对齐到滑道起点的时间

--------------------------------------------------
-- 获取滑道的起点和终点
--------------------------------------------------

local function GetSlidePoints(slide)

	local startAttachment = slide:FindFirstChild("StartPoint")
	local endAttachment = slide:FindFirstChild("EndPoint")

	if startAttachment and endAttachment then
		return startAttachment.WorldPosition, endAttachment.WorldPosition
	end

	-- 如果没有 Attachment，就用滑道自身的大小和朝向估算
	local cf = slide.CFrame
	local halfLength = slide.Size.Z / 2

	local startPos = (cf * CFrame.new(0, 0, -halfLength)).Position
	local endPos = (cf * CFrame.new(0, 0, halfLength)).Position

	return startPos, endPos
end


--------------------------------------------------
-- 果实碰到滑道后的处理
--------------------------------------------------

local function OnFruitTouched(fruit, hit)

	-- 防止重复触发
	if fruit:GetAttribute("OnSlide") then
		return
	end

	-- 只处理带标签的滑道
	if not CollectionService:HasTag(hit, SLIDE_TAG) then
		return
	end

	fruit:SetAttribute("OnSlide", true)

	--------------------------------------------------
	-- 获取起点终点
	--------------------------------------------------

	local startPos, endPos = GetSlidePoints(hit)

	if not startPos or not endPos then
		fruit:SetAttribute("OnSlide", false)
		return
	end

	--------------------------------------------------
	-- 计算方向与时长
	--------------------------------------------------

	local direction = (endPos - startPos).Unit
	local distance = (endPos - startPos).Magnitude
	local duration = distance / SLIDE_SPEED

	--------------------------------------------------
	-- 关闭物理，准备 Tween
	--------------------------------------------------

	fruit.Anchored = true
	fruit.CanCollide = false

	--------------------------------------------------
	-- 先对齐到滑道起点（可选）
	--------------------------------------------------

	local startCFrame = CFrame.lookAt(startPos, startPos + direction)
	local endCFrame = CFrame.lookAt(endPos, endPos + direction)

	local moveToStart = TweenService:Create(
		fruit,
		TweenInfo.new(MOVE_TO_START_TIME, Enum.EasingStyle.Linear),
		{ CFrame = startCFrame }
	)

	moveToStart:Play()
	moveToStart.Completed:Wait()

	--------------------------------------------------
	-- 沿滑道从起点移动到终点
	--------------------------------------------------

	local slideTween = TweenService:Create(
		fruit,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ CFrame = endCFrame }
	)

	slideTween:Play()
	slideTween.Completed:Wait()

	--------------------------------------------------
	-- 恢复物理，继续下落
	--------------------------------------------------

	fruit.Anchored = false
	fruit.CanCollide = true
	fruit.AssemblyLinearVelocity = direction * SLIDE_SPEED

	-- 清除防抖，允许碰到下一个滑道
	fruit:SetAttribute("OnSlide", false)

end


--------------------------------------------------
-- 给果实绑定 Touched
--------------------------------------------------

local function SetupFruit(fruit)

	fruit:SetAttribute("OnSlide", false)

	fruit.Touched:Connect(function(hit)
		OnFruitTouched(fruit, hit)
	end)

end


--------------------------------------------------
-- 生成果实
--------------------------------------------------

local function SpawnFruit(startCFrame)

	local fruit = Instance.new("Part")

	fruit.Name = "Fruit"
	fruit.Shape = Enum.PartType.Ball
	fruit.Size = Vector3.new(1.5, 1.5, 1.5)
	fruit.Color = Color3.fromRGB(255, 80, 80)
	fruit.Material = Enum.Material.SmoothPlastic
	fruit.Anchored = false
	fruit.CanCollide = true
	fruit.CFrame = startCFrame
	fruit.Parent = workspace

	SetupFruit(fruit)

	return fruit

end


--------------------------------------------------
-- 测试：从固定点生成
--------------------------------------------------

-- 假设树顶位置
local spawnCFrame = CFrame.new(0, 30, 0)

local fruit = SpawnFruit(spawnCFrame)

-- 给一个初始速度，让它自然下落
fruit.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
