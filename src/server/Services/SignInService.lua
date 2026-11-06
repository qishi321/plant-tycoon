local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")

local ClaimSignIn = RemoteEvent:WaitForChild("ClaimSignIn")
local GetSignInData = RemoteFunction:WaitForChild("GetSignInData")

local Config = require(
	ReplicatedStorage.Config:WaitForChild("SignInConfig")
)

local DataService = require(
	ServerScriptService.Data:WaitForChild("DataService")
)

--------------------------------------------------
-- 获取日期
--------------------------------------------------

local function GetDateString(timestamp)

	timestamp = timestamp or os.time()

	local utcTime = os.date("!*t", timestamp)

	local localTimestamp =
		os.time(utcTime)
		+ Config.TimeZoneOffset * 60 * 60

	local date = os.date("!*t", localTimestamp)

	return string.format(
		"%04d-%02d-%02d",
		date.year,
		date.month,
		date.day
	)
end

--------------------------------------------------
-- 获取两个日期相差多少天
--------------------------------------------------

local function GetDayDifference(date1, date2)

	if date1 == "" or date2 == "" then
		return math.huge
	end

	local y1, m1, d1 = date1:match("(%d+)-(%d+)-(%d+)")
	local y2, m2, d2 = date2:match("(%d+)-(%d+)-(%d+)")

	if not y1 or not y2 then
		return math.huge
	end

	local t1 = os.time({
		year = tonumber(y1),
		month = tonumber(m1),
		day = tonumber(d1),

		hour = 0,
		min = 0,
		sec = 0,
	})

	local t2 = os.time({
		year = tonumber(y2),
		month = tonumber(m2),
		day = tonumber(d2),

		hour = 0,
		min = 0,
		sec = 0,
	})

	return math.floor(
		math.abs(t2 - t1) / 86400
	)
end

--------------------------------------------------
-- 获取签到状态
--------------------------------------------------

local function GetSignInState(player)

	local data = DataService:GetData(player)

	if not data then
		return nil
	end

	if typeof(data.LoginReward) ~= "table" then

		data.LoginReward = {
			CurrentDay = 1,
			LastClaimDate = "",
		}

	end

	local loginReward = data.LoginReward

	local today = GetDateString()

	local currentDay = tonumber(loginReward.CurrentDay) or 1
	local lastClaimDate = loginReward.LastClaimDate or ""

	local canClaim = false

	if lastClaimDate == "" then

		-- 第一次签到
		currentDay = 1
		canClaim = true

	else

		local difference =
			GetDayDifference(lastClaimDate, today)

		if difference == 0 then

			-- 今天已经签到
			canClaim = false

		elseif difference == 1 then

			-- 正常连续签到
			canClaim = true

		else

			-- 超过一天没签到
			currentDay = 1
			canClaim = true

		end

	end

	return {
		CurrentDay = currentDay,
		LastClaimDate = lastClaimDate,
		Today = today,
		CanClaim = canClaim,
	}
end

--------------------------------------------------
-- 客户端获取签到数据
--------------------------------------------------

GetSignInData.OnServerInvoke = function(player)

	local state = GetSignInState(player)

	if not state then
		return nil
	end

	return state
end

--------------------------------------------------
-- 领取签到
--------------------------------------------------

ClaimSignIn.OnServerEvent:Connect(function(player)

	local state = GetSignInState(player)

	if not state then
		warn("[签到] 玩家数据不存在：", player.Name)
		return
	end

	if not state.CanClaim then

		warn(
			"[签到] 今天已经领取：",
			player.Name
		)

		return
	end

	local day = state.CurrentDay

	local reward = Config.Rewards[day]

	if not reward then

		warn(
			"[签到] 找不到奖励 Day",
			day
		)

		return
	end

	local data = DataService:GetData(player)

	if not data then
		return
	end

	--------------------------------------------------
	-- 发放奖励
	--------------------------------------------------

	if reward.Type == "Money" then

		DataService:AddMoney(
			player,
			reward.Amount
		)

	else

		warn(
			"[签到] 暂时不支持奖励类型：",
			reward.Type
		)

		return
	end

	--------------------------------------------------
	-- 更新签到数据
	--------------------------------------------------

	data.LoginReward = {
		CurrentDay = day >= Config.MaxDay
			and 1
			or day + 1,

		LastClaimDate = state.Today,
	}

	--------------------------------------------------
	-- 保存
	--------------------------------------------------

	DataService:SavePlayer(player)

	print(
		"[签到]",
		player.Name,
		"领取 Day",
		day,
		reward.Name
	)

	--------------------------------------------------
	-- 通知客户端
	--------------------------------------------------

	ClaimSignIn:FireClient(
		player,
		"Success",
		day,
		reward.Name
	)

end)
