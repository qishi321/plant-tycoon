--==================================================
-- Main.server.lua
-- 玩家生命周期管理
--==================================================

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(
	ServerScriptService.Data.DataService
)

local PlotService = require(
	ServerScriptService.Services.PlotService
)

local PlantService = require(
	ServerScriptService.Services.PlantService
)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- 离线收益 UI RemoteEvent
--------------------------------------------------

local OfflineIncomeEvent =
	ReplicatedStorage:FindFirstChild("OfflineIncomeEvent")

if not OfflineIncomeEvent then

	OfflineIncomeEvent =
		Instance.new("RemoteEvent")

	OfflineIncomeEvent.Name =
		"OfflineIncomeEvent"

	OfflineIncomeEvent.Parent =
		ReplicatedStorage

end

--------------------------------------------------
-- 防止重复加载
--------------------------------------------------

local LoadingPlayers = {}


--------------------------------------------------
-- 创建 Leaderstats
--------------------------------------------------

local function CreateLeaderstats(player, data)

	-- 防止重复创建
	local oldLeaderstats = player:FindFirstChild("leaderstats")

	if oldLeaderstats then
		oldLeaderstats:Destroy()
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player


	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = data.Money or 0
	money.Parent = leaderstats

end


--------------------------------------------------
-- 创建玩家 Attributes
--------------------------------------------------

local function CreatePlayerAttributes(player, data)

	local plantData = data.Plant or {}

	player:SetAttribute(
		"DataLoaded",
		true
	)


	player:SetAttribute(
		"PlotLevel",
		data.PlotLevel or 1
	)


	player:SetAttribute(
		"PlantLevel",
		plantData.Level or 0
	)


	player:SetAttribute(
		"PlantHeight",
		plantData.Height or 0
	)


	player:SetAttribute(
		"PlantFruit",
		plantData.Fruit or ""
	)

end


--------------------------------------------------
-- 每10秒记录一次金币收益
--------------------------------------------------

local function StartOfflineIncomeTracker(player)

	task.spawn(function()

		while player.Parent do

			task.wait(10)

			if not player.Parent then
				break
			end

			local data = DataService:GetData(player)

			if not data then
				continue
			end

			local income = DataService:TakeProductionIncome(player)

			-- 只有这10秒确实有收入，才更新离线收益标准
			if income > 0 then
				local data = DataService:GetData(player)
				if data then
					data.OfflineIncomePer10Sec = income
					print("[离线收益] " .. player.Name .. " 最近10秒收益：" .. income)
				end
			end

		end 

	end)

end


--------------------------------------------------
-- 计算离线收益
--------------------------------------------------

local function CalculateOfflineIncome(player)

	local data =
		DataService:GetData(player)

	if not data then
		return 0
	end

	--------------------------------------------------
	-- 上次离开时间
	--------------------------------------------------

	local lastLogout =
		data.LastLogout or 0

	if lastLogout <= 0 then
		return 0
	end

	--------------------------------------------------
	-- 计算离线时间
	--------------------------------------------------

	local currentTime =
		os.time()

	local offlineSeconds =
		currentTime - lastLogout

	if offlineSeconds <= 0 then
		return 0
	end

	--------------------------------------------------
	-- 最多计算8小时
	--------------------------------------------------

	local MAX_OFFLINE_SECONDS =
		8 * 60 * 60

	offlineSeconds =
		math.min(
			offlineSeconds,
			MAX_OFFLINE_SECONDS
		)

	--------------------------------------------------
	-- 获取每10秒收益
	--------------------------------------------------

	local incomePer10Sec =
		data.OfflineIncomePer10Sec or 0

	if incomePer10Sec <= 0 then
		return 0
	end

	--------------------------------------------------
	-- 计算最终离线收益
	--------------------------------------------------

	local income =
		math.floor(
			(offlineSeconds / 10)
			* incomePer10Sec
		)

	if income <= 0 then
		return 0
	end

	--------------------------------------------------
	-- 增加金币
	--
	-- 注意：
	-- 这里不能使用 AddMoney，
	-- 否则离线收益会被再次统计进
	-- 在线10秒收益。
	--------------------------------------------------

	local success =
		DataService:AddMoneyWithoutIncome(
			player,
			income
		)

	if not success then

		warn(
			"[离线收益] 发放失败：",
			player.Name,
			income
		)

		return 0
	end

	--------------------------------------------------
	-- 输出测试信息
	--------------------------------------------------

	print(
		"[离线收益] "
			.. player.Name
			.. " 离线 "
			.. offlineSeconds
			.. " 秒"
			.. "，获得 "
			.. income
			.. " 金币"
	)

	--------------------------------------------------
	-- 返回实际获得的离线收益
	--------------------------------------------------

	return income

end

--------------------------------------------------
-- 玩家加入
--------------------------------------------------

local function PlayerAdded(player)

	--------------------------------------------------
	-- 防止重复加载
	--------------------------------------------------

	if LoadingPlayers[player] then

		warn(
			"[Main] 玩家正在加载中："
				.. player.Name
		)

		return

	end

	LoadingPlayers[player] = true


	--------------------------------------------------
	-- 加载玩家数据
	--------------------------------------------------

	local success, data = pcall(function()

		return DataService:LoadPlayer(player)

	end)


	--------------------------------------------------
	-- 数据加载失败
	--------------------------------------------------

	if not success or not data then

		warn(
			"[Main] 玩家数据加载失败："
				.. player.Name
		)

		LoadingPlayers[player] = nil

		player:Kick(
			"数据加载失败，请重新进入游戏"
		)

		return
	end


	--------------------------------------------------
	-- 创建 Leaderstats
	--------------------------------------------------

	CreateLeaderstats(
		player,
		data
	)


	--------------------------------------------------
	-- 创建玩家 Attributes
	--------------------------------------------------

	CreatePlayerAttributes(
		player,
		data
	)


	--------------------------------------------------
	-- 分配土地
	--------------------------------------------------

	local plot = PlotService:AssignPlot(
		player
	)


	--------------------------------------------------
	-- 没有土地
	--------------------------------------------------

	if not plot then

		warn(
			"[Main] 没有可用土地："
				.. player.Name
		)

		DataService:RemovePlayer(player)

		LoadingPlayers[player] = nil

		player:Kick(
			"当前没有可用土地"
		)

		return
	end


	--------------------------------------------------
	-- 保存土地名称
	--------------------------------------------------

	player:SetAttribute(
		"PlotName",
		plot.Name
	)


	--------------------------------------------------
	-- 加载玩家自己的植物
	--------------------------------------------------

	local plantSuccess, plantError = pcall(function()

		PlantService:LoadPlayerPlant(
			player
		)

	end)


	if not plantSuccess then

		warn(
			"[Main] 加载植物失败：",
			player.Name,
			plantError
		)

	end


	--------------------------------------------------
	-- 计算离线收益
	--------------------------------------------------

	local offlineIncome =
		CalculateOfflineIncome(player)

	--------------------------------------------------
	-- 清空当前10秒统计
	--------------------------------------------------

	data._Current10SecIncome = 0

	--------------------------------------------------
	-- 如果有离线收益，通知客户端显示UI
	--------------------------------------------------

	if offlineIncome > 0 then

		OfflineIncomeEvent:FireClient(
			player,
			offlineIncome
		)

	end

	--------------------------------------------------
	-- 开始新的10秒收益统计
	--------------------------------------------------

	StartOfflineIncomeTracker(player)


	--------------------------------------------------
	-- 玩家初始化完成
	--------------------------------------------------

	print(
		"[Main] 玩家初始化完成："
			.. player.Name
	)


	--------------------------------------------------
	-- 加载完成
	--------------------------------------------------

	LoadingPlayers[player] = nil

end


--------------------------------------------------
-- 玩家离开
--------------------------------------------------

local function PlayerRemoving(player)

	--------------------------------------------------
	-- 先保存当前植物到 DataService 缓存
	--------------------------------------------------

	local plantSuccess, plantError = pcall(function()

		PlantService:SavePlayerPlant(
			player
		)

	end)


	if not plantSuccess then

		warn(
			"[Main] 保存植物失败：",
			player.Name,
			plantError
		)

	end


	--------------------------------------------------
	-- 保存所有玩家数据
	--------------------------------------------------

	local saveSuccess, saveError = pcall(function()

		DataService:SavePlayer(
			player
		)

	end)


	if not saveSuccess then

		warn(
			"[Main] 玩家数据保存失败：",
			player.Name,
			saveError
		)

	end


	--------------------------------------------------
	-- 释放土地
	--------------------------------------------------

	PlotService:ReleasePlot(
		player
	)


	--------------------------------------------------
	-- 删除玩家缓存
	--------------------------------------------------

	DataService:RemovePlayer(
		player
	)


	--------------------------------------------------
	-- 清除加载状态
	--------------------------------------------------

	LoadingPlayers[player] = nil


	print(
		"[Main] 玩家离开处理完成："
			.. player.Name
	)

end


--------------------------------------------------
-- 玩家事件
--------------------------------------------------

Players.PlayerAdded:Connect(
	PlayerAdded
)

Players.PlayerRemoving:Connect(
	PlayerRemoving
)


--------------------------------------------------
-- 处理脚本启动前已经存在的玩家
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
	) do

	task.spawn(function()

		PlayerAdded(player)

	end)

end


--------------------------------------------------
-- 服务器关闭
--------------------------------------------------

game:BindToClose(function()

	print(
		"[Main] 服务器正在关闭，保存玩家数据..."
	)


	local players = Players:GetPlayers()


	--------------------------------------------------
	-- 保存所有玩家
	--------------------------------------------------

	for _, player in ipairs(players) do

		task.spawn(function()

			--------------------------------------------------
			-- 先保存植物到缓存
			--------------------------------------------------

			pcall(function()

				PlantService:SavePlayerPlant(
					player
				)

			end)


			--------------------------------------------------
			-- 再保存 DataStore
			--------------------------------------------------

			pcall(function()

				DataService:SavePlayer(
					player
				)

			end)

		end)

	end


	--------------------------------------------------
	-- 等待保存完成
	--------------------------------------------------

	task.wait(5)

	print(
		"[Main] 服务器关闭保存完成"
	)

end)


--------------------------------------------------
-- 自动保存
--------------------------------------------------

task.spawn(function()

	while true do

		--------------------------------------------------
		-- 每 5 分钟
		--------------------------------------------------

		task.wait(300)


		print(
			"[Main] 开始自动保存玩家数据..."
		)


		for _, player in ipairs(
			Players:GetPlayers()
			) do

			task.spawn(function()

				--------------------------------------------------
				-- 先把植物当前状态写入缓存
				--------------------------------------------------

				local plantSuccess, plantError = pcall(function()

					PlantService:SavePlayerPlant(
						player
					)

				end)


				if not plantSuccess then

					warn(
						"[Main] 自动保存植物失败：",
						player.Name,
						plantError
					)

				end


				--------------------------------------------------
				-- 保存 DataStore
				--------------------------------------------------

				local saveSuccess, saveError = pcall(function()

					DataService:SavePlayer(
						player
					)

				end)


				if not saveSuccess then

					warn(
						"[Main] 自动保存玩家数据失败：",
						player.Name,
						saveError
					)

				end

			end)

		end


		print(
			"[Main] 自动保存完成"
		)

	end

end)

