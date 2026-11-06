local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerui = script.Parent.Parent


local GooseSlotGui = playerui:WaitForChild("GooseSlotGui")

local beibaoui = GooseSlotGui:WaitForChild("beibao")
local shopui = GooseSlotGui:WaitForChild("shop")
local guoshi = GooseSlotGui:WaitForChild("guoshi")
local guanbi1 =beibaoui.guanbi
local guanbi2 =shopui.guanbi
local guanbi3 =guoshi.guanbi


local function Close()

	beibaoui.Visible = false
	shopui.Visible = false
	guoshi.Visible = false

end

guanbi1.Activated:Connect(function()

	Close()
	
	if _G.ClosePlantCamera then
		_G.ClosePlantCamera()
	end

end)

guanbi2.Activated:Connect(function()

	Close()

end)


guanbi3.Activated:Connect(function()

	Close()

end)




