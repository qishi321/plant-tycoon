local ReplicatedStorage = game:GetService("ReplicatedStorage")

local button = script.Parent

print("[购买系统] LocalScript 已启动")
print("[购买系统] button =", button:GetFullName())

local shopui = button.Parent

print("[购买系统] shop =", shopui:GetFullName())

local wuping = shopui:WaitForChild("wuping")

local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")

local BuyGoose = RemoteFunction:WaitForChild("BuyGoose")

print("[购买系统] BuyGoose 找到了")


--------------------------------------------------
-- 点击购买
--------------------------------------------------

button.Activated:Connect(function()

	print("[购买系统] 点击购买按钮")

	--------------------------------------------------
	-- 获取当前选择的商品
	--------------------------------------------------

	local gooseId = wuping.Value

	print("[购买系统] 当前商品 =", gooseId)

	if gooseId == "" then

		warn("[购买系统] 没有选择鹅化物")

		return
	end


	--------------------------------------------------
	-- 请求服务器
	--------------------------------------------------

	print("[购买系统] 正在请求购买：", gooseId)

	local success, message = BuyGoose:InvokeServer(gooseId)


	--------------------------------------------------
	-- 购买结果
	--------------------------------------------------

	if success then

		print(
			"[购买系统] 购买成功：",
			gooseId
		)

	else

		warn(
			"[购买系统] 购买失败：",
			message
		)

	end

end)
