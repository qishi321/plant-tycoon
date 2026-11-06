--==================================================
-- 玩家默认数据模板
-- DefaultData
--==================================================

local DefaultData = {
	Money = 1000,
	LastLogout = 0,
	PlotLevel = 1,

	Plant = {
		Name = "",
		Level = 0,
		Height = 0,
		Growth = 0,
		Fruit = "",
		GooseSlots = {}
	},

	GooseInventory = {},
	FruitInventory = {"Apple"},
	-- 每10秒金币收益
	OfflineIncomePer10Sec = 0,
	ChestNextDraw = 0,
	-- 七天签到
	LoginReward = {
		CurrentDay = 1,
		LastClaimDate = "",
		-- 是否可以领取
		CanClaim = true,
	},
}

return DefaultData


