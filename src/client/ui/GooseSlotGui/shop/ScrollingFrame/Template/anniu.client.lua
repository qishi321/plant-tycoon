local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerui = player:WaitForChild("PlayerGui")


local GooseSlotGui = playerui:WaitForChild("GooseSlotGui")
local shopui = GooseSlotGui:WaitForChild("shop")
local goumai = shopui:WaitForChild("goumai")
local wuping = shopui:WaitForChild("wuping")
local ScrollingFrame = shopui:WaitForChild("ScrollingFrame")

local anuiu = script.Parent


local function qinli()
	
	for _,template in pairs(ScrollingFrame:GetChildren()) do
		if template.Name ~= "Template" and template.ClassName == "ImageButton" then
			template.UIStroke.Transparency = 1
		end
		
	end
	
end

anuiu.Activated:Connect(function()
	qinli()

	goumai.Visible = true
	anuiu.UIStroke.Transparency = 0
	wuping.Value = anuiu.Name
	print(wuping.Value)

end)

