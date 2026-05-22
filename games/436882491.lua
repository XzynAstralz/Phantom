local gui = Instance.new("ScreenGui")
gui.Name = "PhantomNotice"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bg.BorderSizePixel = 0
bg.Parent = gui

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 0.7, 0)
text.BackgroundTransparency = 1
text.Text = "Phantom is down for maintenance.\nCheck the Discord for updates.\nSorry 😢"
text.TextColor3 = Color3.fromRGB(255, 255, 255)
text.Font = Enum.Font.GothamBold
text.TextScaled = true
text.Parent = bg

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 300, 0, 60)
button.Position = UDim2.new(0.5, -150, 0.8, 0)
button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
button.TextColor3 = Color3.fromRGB(255, 80, 80)
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.Text = "Shutdown Phantom"
button.Parent = bg

Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

local func = getgenv().phantom.Shutdown()

button.MouseButton1Click:Connect(function()
    if func then
        pcall(func)
    end

    if text then
        text:Destroy()
    end

    if bg then
        bg:Destroy()
    end

    if gui then
        gui:Destroy()
    end
end)
