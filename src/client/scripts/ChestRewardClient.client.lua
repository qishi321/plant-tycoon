local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local RemoteEvent =
	ReplicatedStorage:WaitForChild("RemoteEvent")

local ChestDrawResult =
	RemoteEvent:WaitForChild("ChestDrawResult")

--------------------------------------------------
-- 找到玩家自己的土地
--------------------------------------------------

local function GetPlayerPlot()

	local plotName =
		player:GetAttribute("PlotName")

	if not plotName then
		return nil
	end

	local map =
		workspace:FindFirstChild("Grow A Garden map")

	if not map then
		return nil
	end

	return map:FindFirstChild(
		tostring(plotName)
	)

end

--------------------------------------------------
-- 获取奖励 TextLabel
--------------------------------------------------

local function GetRewardTextLabel()

	local plot =
		GetPlayerPlot()

	if not plot then
		return nil
	end

	local chest =
		plot:FindFirstChild("Chest")

	if not chest then
		return nil
	end

	local jiangpin =
		chest:FindFirstChild("jiangpin")

	if not jiangpin then
		return nil
	end

	local jiangpinFrame =
		jiangpin:FindFirstChild("jiangpin")

	if not jiangpinFrame then
		return nil
	end

	local textLabel =
		jiangpinFrame:FindFirstChild("TextLabel")

	if not textLabel then
		return nil
	end

	return textLabel

end

--------------------------------------------------
-- 显示奖励
--------------------------------------------------

local rewardShowId = 0

local function ShowReward(fruitName)

	local textLabel =
		GetRewardTextLabel()

	if not textLabel then

		warn(
			"[Chest] 找不到奖励 TextLabel"
		)

		return
	end

	--------------------------------------------------
	-- 防止旧的3秒计时把新的奖励提前隐藏
	--------------------------------------------------

	rewardShowId += 1

	local currentShowId =
		rewardShowId

	--------------------------------------------------
	-- 显示奖励
	--------------------------------------------------

	textLabel.Text =
		"恭喜获得：" .. tostring(fruitName)

	textLabel.Visible = true

	print(
		"[Chest] 显示抽奖奖励：",
		fruitName
	)

	--------------------------------------------------
	-- 3秒后隐藏
	--------------------------------------------------

	task.delay(3, function()

		-- 如果期间又显示了新的奖励
		-- 就不要把新的奖励隐藏掉

		if currentShowId ~= rewardShowId then
			return
		end

		if textLabel
			and textLabel.Parent then

			textLabel.Text = ""
			textLabel.Visible = false

		end

	end)

end

--------------------------------------------------
-- 抽奖结果
--------------------------------------------------

ChestDrawResult.OnClientEvent:Connect(
	function(success, fruitName, remaining)

		--------------------------------------------------
		-- 抽奖成功
		--------------------------------------------------

		if success then

			if fruitName then

				ShowReward(fruitName)

			end

			return
		end

		--------------------------------------------------
		-- 冷却中
		--------------------------------------------------

		print(
			"[Chest] 还需要等待：",
			remaining,
			"秒"
		)

	end
)
