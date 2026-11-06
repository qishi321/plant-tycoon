local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

--------------------------------------------------
-- 地图
--------------------------------------------------

local map =
	workspace:WaitForChild("Grow A Garden map")

--------------------------------------------------
-- 等待玩家的 PlotName 属性
-- GoosePlacementClient 也是用这个属性定位地块的
--------------------------------------------------

local function WaitForPlotName()

	local timeout = 30
	local startTime = os.clock()

	while os.clock() - startTime < timeout do

		local plotName =
			player:GetAttribute("PlotName")

		if plotName and plotName ~= "" then
			return plotName
		end

		task.wait(0.1)

	end

	return nil

end

--------------------------------------------------
-- 获取玩家自己的 Chest
--------------------------------------------------

local function GetPlayerChest()

	local plotName =
		WaitForPlotName()

	if not plotName then

		warn(
			"[ChestClient] 等待 PlotName 超时"
		)

		return nil

	end

	--------------------------------------------------
	-- 等待地块
	--------------------------------------------------

	local plot
	local plotTimeout = 30
	local plotStart = os.clock()

	while os.clock() - plotStart < plotTimeout do

		plot =
			map:FindFirstChild(plotName)

		if plot then
			break
		end

		task.wait(0.1)

	end

	if not plot then

		warn(
			"[ChestClient] 找不到地块：",
			plotName
		)

		return nil

	end

	--------------------------------------------------
	-- 等待 Chest
	--------------------------------------------------

	local chest =
		plot:WaitForChild("Chest", 30)

	if not chest then

		warn(
			"[ChestClient] 地块里找不到 Chest：",
			plotName
		)

		return nil

	end

	return chest

end

--------------------------------------------------
-- 获取 Chest 上的 BillboardGui 和 TextLabel
--------------------------------------------------

local chest = GetPlayerChest()

if not chest then
	warn("[ChestClient] 无法获取玩家自己的 Chest，脚本停止")
	return
end

local billboardGui =
	chest:WaitForChild("BillboardGui", 30)

if not billboardGui then
	warn("[ChestClient] Chest 里找不到 BillboardGui")
	return
end

local textLabel =
	billboardGui:WaitForChild("TextLabel", 30)

if not textLabel then
	warn("[ChestClient] BillboardGui 里找不到 TextLabel")
	return
end

--------------------------------------------------
-- Remote
--------------------------------------------------

local RemoteFunction =
	ReplicatedStorage:WaitForChild("RemoteFunction")

local GetChestCooldown =
	RemoteFunction:WaitForChild("GetChestCooldown")

local RemoteEvent =
	ReplicatedStorage:WaitForChild("RemoteEvent")

local ChestDrawResult =
	RemoteEvent:WaitForChild("ChestDrawResult")

--------------------------------------------------
-- 下一次抽奖时间
--------------------------------------------------

local nextDrawTime = 0

--------------------------------------------------
-- 格式化时间
--------------------------------------------------

local function FormatTime(seconds)

	seconds =
		math.max(
			0,
			math.floor(seconds)
		)

	local minutes =
		math.floor(
			seconds / 60
		)

	local remainingSeconds =
		seconds % 60

	return string.format(
		"%02d:%02d",
		minutes,
		remainingSeconds
	)

end

--------------------------------------------------
-- 获取服务器上的冷却
--------------------------------------------------

local success, result =
	pcall(function()

		return GetChestCooldown:InvokeServer()

	end)

if success and typeof(result) == "number" then

	nextDrawTime = result

end

--------------------------------------------------
-- 抽奖结果
--------------------------------------------------

ChestDrawResult.OnClientEvent:Connect(
	function(
		success,
		fruitName,
		remaining
	)

		if success then

			nextDrawTime =
				os.time() + 300

			print(
				"[ChestClient] 获得果实：",
				fruitName
			)

		else

			if typeof(remaining) == "number" then

				nextDrawTime =
					os.time() + remaining

			end

		end

	end
)

--------------------------------------------------
-- 更新 TextLabel
--------------------------------------------------

while true do

	--------------------------------------------------
	-- 每次循环检查 Chest 是否还存在
	-- 如果地块被重建，就重新获取
	--------------------------------------------------

	if not chest or not chest.Parent then

		print(
			"[ChestClient] Chest 丢失，重新获取"
		)

		local newChest =
			GetPlayerChest()

		if newChest then

			chest =
				newChest

			local newBillboard =
				chest:WaitForChild("BillboardGui", 10)

			if newBillboard then

				billboardGui =
					newBillboard

				local newLabel =
					billboardGui:WaitForChild("TextLabel", 10)

				if newLabel then
					textLabel = newLabel
				end

			end

		end

	end

	--------------------------------------------------
	-- 更新文本
	--------------------------------------------------

	if textLabel and textLabel.Parent then

		local remaining =
			nextDrawTime - os.time()

		if remaining <= 0 then

			textLabel.Text =
				"可以抽奖！"

		else

			textLabel.Text =
				"下次抽奖：" ..
				FormatTime(remaining)

		end

	end

	task.wait(1)

end