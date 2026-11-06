local GooseConfig = {

	--------------------------------------------------
	-- 🟫 Common 普通枝条
	--------------------------------------------------

	["Goose01"] = {
		Name = "枯木枝",
		Description = "一根看起来毫不起眼的树枝，但它至少还能发挥一点作用。",
		Rarity = "Common",
		Price = 500,
		Icon = "Goose01",

		Effect = {
			Type = "SellPrice",
			Value = 10,
			Text = "果实售价 +10%",
		},
	},

	

	["Goose03"] = {
		Name = "多果枝",
		Description = "这根枝条上长满了小芽，看起来很贪心。",
		Rarity = "Common",
		Price = 750,
		Icon = "Goose03",

		Effect = {
			Type = "ExtraFruit",
			Value = 1,
			Text = "每次生产额外 +1 果实",
		},
	},

	


	--------------------------------------------------
	-- 🟩 Uncommon 稀有枝条
	--------------------------------------------------

	["Goose05"] = {
		Name = "金芽枝",
		Description = "枝条上长着金色嫩芽，据说它非常喜欢金币。",
		Rarity = "Uncommon",
		Price = 2500,
		Icon = "Goose05",

		Effect = {
			Type = "SellPrice",
			Value = 20,
			Text = "果实售价 +20%",
		},
	},


	["Goose08"] = {
		Name = "丰收枝",
		Description = "这根枝条似乎认为一个果实远远不够。",
		Rarity = "Uncommon",
		Price = 4000,
		Icon = "Goose08",

		Effect = {
			Type = "ExtraFruit",
			Value = 2,
			Text = "每次生产额外 +2 果实",
		},
	},


	--------------------------------------------------
	-- 🟦 Rare 稀有枝条
	--------------------------------------------------

	["Goose09"] = {
		Name = "黄金枝",
		Description = "整根枝条都散发着淡淡的金色光芒。",
		Rarity = "Rare",
		Price = 12000,
		Icon = "Goose09",

		Effect = {
			Type = "SellPrice",
			Value = 35,
			Text = "果实售价 +35%",
		},
	},


	--------------------------------------------------
	-- 🟪 Epic 史诗枝条
	--------------------------------------------------

	["Goose13"] = {
		Name = "钻石枝",
		Description = "枝条内部似乎生长着天然钻石。",
		Rarity = "Epic",
		Price = 75000,
		Icon = "Goose13",

		Effect = {
			Type = "SellPrice",
			Value = 60,
			Text = "果实售价 +60%",
		},
	},


	["Goose15"] = {
		Name = "黄金果枝",
		Description = "它本身不会产生黄金，但果实似乎特别喜欢在它附近生长。",
		Rarity = "Epic",
		Price = 120000,
		Icon = "Goose15",

		Effect = {
			Type = "PriceMultiplierChance",
			Chance = 8,
			Multiplier = 3,
			Text = "8% 概率使果实售价 ×3",
		},
	},


	--------------------------------------------------
	-- 🟨 Legendary 传说枝条
	--------------------------------------------------



	--------------------------------------------------
	-- 🟥 Mythic 神话枝条
	--------------------------------------------------




}

return GooseConfig
