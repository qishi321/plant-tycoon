--==================================================
-- DataService
--==================================================

local ServerScriptService = game:GetService("ServerScriptService")

local DataStore2 = require(
	ServerScriptService:WaitForChild("DataStore2")
)

local DefaultData = require(
	script.Parent:WaitForChild("DefaultData")
)

--------------------------------------------------
-- DataStore2 Combine
--------------------------------------------------

DataStore2.Combine(
	"PlayerData_Test_024",
	"PlayerData",
	"Money",
	"LastLogout",
	"PlotLevel",
	"Plant",
	"GooseInventory",
	"FruitInventory",
	"OfflineIncomePer10Sec",
	"ChestNextDraw",
	"LoginReward"
)

local DataService = {}

--------------------------------------------------
-- 玩家数据缓存
--------------------------------------------------

local PlayerDataCache = {}

--------------------------------------------------
-- 深度复制
--------------------------------------------------

local function DeepCopy(value)

	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, childValue in pairs(value) do
		copy[key] = DeepCopy(childValue)
	end

	return copy
end

--------------------------------------------------
-- 创建默认数据
--------------------------------------------------

local function CreateDefaultData()

	return DeepCopy(DefaultData)

end

--------------------------------------------------
-- 加载玩家
--------------------------------------------------

function DataService:LoadPlayer(player)

	--------------------------------------------------
	-- 防止重复加载
	--------------------------------------------------
	
	local offlineIncomeStore = DataStore2(
		"OfflineIncomePer10Sec",
		player
	)
	
	local chestNextDrawStore = DataStore2(
		"ChestNextDraw",
		player
	)

	if PlayerDataCache[player] then
		return PlayerDataCache[player]
	end

	print(
		"[DataService] 开始加载："
			.. player.Name
	)

	--------------------------------------------------
	-- 默认数据
	--------------------------------------------------

	local data = CreateDefaultData()

	--------------------------------------------------
	-- DataStore2
	--------------------------------------------------

	local moneyStore = DataStore2(
		"Money",
		player
	)

	local lastLogoutStore = DataStore2(
		"LastLogout",
		player
	)

	local plotLevelStore = DataStore2(
		"PlotLevel",
		player
	)

	local plantStore = DataStore2(
		"Plant",
		player
	)

	local gooseInventoryStore = DataStore2(
		"GooseInventory",
		player
	)

	local fruitInventoryStore = DataStore2(
		"FruitInventory",
		player
	)
	
	local offlineIncomeStore = DataStore2(
		"OfflineIncomePer10Sec",
		player
	)
	
	local loginRewardStore = DataStore2("LoginReward", player)
	
	--------------------------------------------------
	-- 读取数据
	--------------------------------------------------

	data.Money = moneyStore:Get(
		data.Money
	)

	data.LastLogout = lastLogoutStore:Get(
		data.LastLogout
	)

	data.PlotLevel = plotLevelStore:Get(
		data.PlotLevel
	)

	data.Plant = plantStore:Get(
		data.Plant
	)

	data.GooseInventory = gooseInventoryStore:Get(
		data.GooseInventory
	)

	data.FruitInventory = fruitInventoryStore:Get(
		data.FruitInventory
	)
	
	data.OfflineIncomePer10Sec =
		offlineIncomeStore:Get(
			data.OfflineIncomePer10Sec or 0
		)
	
	data.ChestNextDraw =
		chestNextDrawStore:Get(
			data.ChestNextDraw or 0
		)
	
	data.LoginReward = loginRewardStore:Get(data.LoginReward)
	
	--------------------------------------------------
	-- 确保 FruitInventory 是数组
	--------------------------------------------------

	if typeof(data.FruitInventory) ~= "table" then
		data.FruitInventory = {}
	end

	--------------------------------------------------
	-- 放入缓存
	--------------------------------------------------

	PlayerDataCache[player] = data

	print(
		"[DataService] 加载完成："
			.. player.Name
	)

	return data
end

--------------------------------------------------
-- 获取全部数据
--------------------------------------------------

function DataService:GetData(player)

	return PlayerDataCache[player]

end

--------------------------------------------------
-- 获取某个数据
--------------------------------------------------

function DataService:GetValue(player, key)

	local data = PlayerDataCache[player]

	if not data then

		warn(
			"[DataService] 找不到玩家数据："
				.. player.Name
		)

		return nil
	end

	return data[key]
end

--------------------------------------------------
-- 修改数据
--------------------------------------------------

function DataService:SetData(
	player,
	key,
	value
)

	local data = PlayerDataCache[player]

	if not data then

		warn(
			"[DataService] SetData 玩家数据不存在："
				.. player.Name
		)

		return false
	end

	data[key] = value

	return true
end

--------------------------------------------------
-- 修改植物数据
--------------------------------------------------

function DataService:SetPlantData(
	player,
	plantData
)

	local data = PlayerDataCache[player]

	if not data then

		warn(
			"[DataService] 玩家数据不存在："
				.. player.Name
		)

		return false
	end

	data.Plant = plantData

	return true
end

--------------------------------------------------
-- 设置金币
--------------------------------------------------

function DataService:SetMoney(
	player,
	amount
)

	local data = PlayerDataCache[player]

	if not data then
		return false
	end

	amount = math.max(
		0,
		amount
	)

	data.Money = amount

	--------------------------------------------------
	-- 更新 Leaderstats
	--------------------------------------------------

	local leaderstats =
		player:FindFirstChild("leaderstats")

	if leaderstats then

		local moneyValue =
			leaderstats:FindFirstChild("Money")

		if moneyValue then
			moneyValue.Value = amount
		end

	end

	return true
end

--------------------------------------------------
-- 增加金币
--------------------------------------------------

function DataService:AddMoney(player, amount)

	local data = PlayerDataCache[player]

	if not data then
		return false
	end

	--------------------------------------------------
	-- 记录实际获得的金币
	--------------------------------------------------

	if amount > 0 then

		data._Current10SecIncome =
			(data._Current10SecIncome or 0)
			+ amount

	end

	--------------------------------------------------
	-- 修改金币
	--------------------------------------------------

	local newAmount =
		data.Money + amount

	if newAmount < 0 then
		newAmount = 0
	end

	return self:SetMoney(
		player,
		newAmount
	)
end

--------------------------------------------------
-- 添加果实种类
--
-- FruitInventory 示例：
--
-- {
--     "Apple",
--     "Banana",
--     "Orange"
-- }
--
-- 同一种果实只保存一次
--------------------------------------------------

function DataService:AddFruit(
	player,
	fruitName
)

	if typeof(fruitName) ~= "string" then

		warn(
			"[DataService] 果实名称错误：",
			fruitName
		)

		return false
	end

	local data =
		PlayerDataCache[player]

	if not data then

		warn(
			"[DataService] 玩家数据不存在：",
			player.Name
		)

		return false
	end

	--------------------------------------------------
	-- 确保背包存在
	--------------------------------------------------

	if typeof(data.FruitInventory) ~= "table" then
		data.FruitInventory = {}
	end

	--------------------------------------------------
	-- 检查是否已经拥有
	--------------------------------------------------

	for _, ownedFruit in ipairs(
		data.FruitInventory
		) do

		if ownedFruit == fruitName then

			-- 已经拥有，不重复添加
			return true
		end

	end

	--------------------------------------------------
	-- 第一次获得这个果实
	--------------------------------------------------

	table.insert(
		data.FruitInventory,
		fruitName
	)

	print(
		"[DataService] 玩家获得新果实：",
		player.Name,
		fruitName
	)

	return true
end

--------------------------------------------------
-- 检查玩家是否拥有某种果实
--------------------------------------------------

function DataService:HasFruit(
	player,
	fruitName
)

	if typeof(fruitName) ~= "string" then
		return false
	end

	local data =
		PlayerDataCache[player]

	if not data then
		return false
	end

	for _, ownedFruit in ipairs(
		data.FruitInventory or {}
		) do

		if ownedFruit == fruitName then
			return true
		end

	end

	return false
end

--------------------------------------------------
-- 获取玩家所有果实
--------------------------------------------------

function DataService:GetFruitInventory(
	player
)

	local data =
		PlayerDataCache[player]

	if not data then
		return {}
	end

	if typeof(data.FruitInventory) ~= "table" then
		data.FruitInventory = {}
	end

	return data.FruitInventory
end

--------------------------------------------------
-- 保存玩家
--------------------------------------------------

function DataService:SavePlayer(player)
	
	

	local data =
		PlayerDataCache[player]

	if not data then

		warn(
			"[DataService] 找不到玩家数据："
				.. player.Name
		)

		return false
	end

	--------------------------------------------------
	-- 更新最后离开时间
	--------------------------------------------------

	data.LastLogout = os.time()

	--------------------------------------------------
	-- 更新 DataStore2
	--------------------------------------------------

	DataStore2(
		"Money",
		player
	):Set(data.Money)

	DataStore2(
		"LastLogout",
		player
	):Set(data.LastLogout)

	DataStore2(
		"PlotLevel",
		player
	):Set(data.PlotLevel)

	DataStore2(
		"Plant",
		player
	):Set(data.Plant)

	DataStore2(
		"GooseInventory",
		player
	):Set(data.GooseInventory)

	DataStore2(
		"FruitInventory",
		player
	):Set(data.FruitInventory)
	
	DataStore2(
		"OfflineIncomePer10Sec",
		player
	):Set(
		data.OfflineIncomePer10Sec or 0
	)
	
	DataStore2(
		"ChestNextDraw",
		player
	):Set(
		data.ChestNextDraw or 0
	)
	
	DataStore2("LoginReward", player):Set(data.LoginReward)

	--------------------------------------------------
	-- Combine 后保存一次
	--------------------------------------------------

	local success, errorMessage =
		pcall(function()

			DataStore2(
				"Money",
				player
			):Save()

		end)

	if not success then

		warn(
			"[DataService] 保存失败：",
			player.Name,
			errorMessage
		)

		return false
	end

	print(
		"[DataService] 保存成功："
			.. player.Name
	)

	return true
end

--------------------------------------------------
-- 删除缓存
--------------------------------------------------

function DataService:RemovePlayer(player)

	PlayerDataCache[player] = nil

end

function DataService:AddMoneyWithoutIncome(
	player,
	amount
)

	local data =
		PlayerDataCache[player]

	if not data then
		return false
	end

	local newAmount =
		data.Money + amount

	if newAmount < 0 then
		newAmount = 0
	end

	return self:SetMoney(
		player,
		newAmount
	)
end

return DataService