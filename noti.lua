local NotificationSystem = {
    notifications = {},
    spacing = 90,
    gui = nil,
    position = "BottomRight" -- "TopRight", "BottomRight", "TopLeft", "BottomLeft"
}

local function CreateGui()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    if playerGui:FindFirstChild("NotificationSystem") then
        return playerGui:FindFirstChild("NotificationSystem")
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NotificationSystem"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    return screenGui
end

NotificationSystem.gui = CreateGui()

function NotificationSystem:GetPosition(index)
    local positions = {
        TopRight = {
            start = UDim2.new(1, 50, 0, 20),
            target = function(i) return UDim2.new(1, -370, 0, 20 + ((i - 1) * self.spacing)) end,
            anchor = Vector2.new(0, 0)
        },
        BottomRight = {
            start = UDim2.new(1, 50, 1, -20),
            target = function(i) return UDim2.new(1, -370, 1, -20 - (i * self.spacing)) end,
            anchor = Vector2.new(0, 1)
        },
        TopLeft = {
            start = UDim2.new(0, -370, 0, 20),
            target = function(i) return UDim2.new(0, 20, 0, 20 + ((i - 1) * self.spacing)) end,
            anchor = Vector2.new(0, 0)
        },
        BottomLeft = {
            start = UDim2.new(0, -370, 1, -20),
            target = function(i) return UDim2.new(0, 20, 1, -20 - (i * self.spacing)) end,
            anchor = Vector2.new(0, 1)
        }
    }
    
    return positions[self.position] or positions.BottomRight
end

function NotificationSystem:UpdatePositions()
    local posData = self:GetPosition()
    
    for i, notif in ipairs(self.notifications) do
        if notif and notif.Parent then
            notif:TweenPosition(
                posData.target(i),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.3,
                true
            )
        end
    end
end

function NotificationSystem:Notify(title, message, duration, notifType)
    duration = duration or 3
    notifType = notifType or "Info"
    
    local colors = {
        Info = Color3.fromRGB(45, 45, 45),
        Success = Color3.fromRGB(34, 139, 34),
        Warning = Color3.fromRGB(255, 165, 0),
        Error = Color3.fromRGB(220, 20, 60)
    }
    
    local bgColor = colors[notifType] or colors.Info
    local posData = self:GetPosition()
    
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 350, 0, 80)
    notification.Position = posData.start
    notification.AnchorPoint = posData.anchor
    notification.BackgroundColor3 = bgColor
    notification.BorderSizePixel = 0
    notification.Parent = self.gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.8
    stroke.Parent = notification
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -60, 0, 25)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notification
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -60, 0, 35)
    messageLabel.Position = UDim2.new(0, 15, 0, 35)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    messageLabel.TextSize = 13
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.TextWrapped = true
    messageLabel.Parent = notification
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 5)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeButton.TextSize = 24
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = notification
    
    closeButton.MouseEnter:Connect(function()
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    
    closeButton.MouseLeave:Connect(function()
        closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    end)
    
    table.insert(self.notifications, notification)
    self:UpdatePositions()
    
    local function closeNotification()
        for i, notif in ipairs(self.notifications) do
            if notif == notification then
                table.remove(self.notifications, i)
                break
            end
        end
        
        notification:TweenPosition(
            posData.start,
            Enum.EasingDirection.In,
            Enum.EasingStyle.Back,
            0.3,
            true,
            function()
                notification:Destroy()
                self:UpdatePositions()
            end
        )
    end
    
    closeButton.MouseButton1Click:Connect(closeNotification)
    
    if duration > 0 then
        task.delay(duration, function()
            if notification and notification.Parent then
                closeNotification()
            end
        end)
    end
end
