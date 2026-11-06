local SignInConfig = {

	-- 每日奖励
	-- 想改奖励直接改这里
	Rewards = {

		[1] = {
			Name = "1000金币",
			Type = "Money",
			Amount = 1000,
		},

		[2] = {
			Name = "2000金币",
			Type = "Money",
			Amount = 2000,
		},

		[3] = {
			Name = "3000金币",
			Type = "Money",
			Amount = 3000,
		},

		[4] = {
			Name = "5000金币",
			Type = "Money",
			Amount = 5000,
		},

		[5] = {
			Name = "8000金币",
			Type = "Money",
			Amount = 8000,
		},

		[6] = {
			Name = "10000金币",
			Type = "Money",
			Amount = 10000,
		},

		[7] = {
			Name = "20000金币",
			Type = "Money",
			Amount = 20000,
		},
	},

	-- 台湾时间 UTC+8
	-- 如果以后想改成其他时区，只改这里
	TimeZoneOffset = 8,

	MaxDay = 7,
}

return SignInConfig
