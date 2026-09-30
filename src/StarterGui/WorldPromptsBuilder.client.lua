-- Walk up to something in your forge and press E: prompts named "OpenMenu_<Gui>" open that menu.
-- (The Anvil's own prompt, "AnvilPrompt", is handled by AnvilMenuBuilder.)
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if player ~= LocalPlayer then return end
    local target = prompt.Name:match("^OpenMenu_(.+)$")
    if not target then return end
    local gui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(target)
    if gui then gui.Enabled = true end
end)
