-- Key Checker Loader (MongoDB via Railway API)
local HttpService = game:GetService("HttpService")

-- Config - THAY URL RAILWAY CỦA BẠN
local API_URL = "https://whitelist-production-f5b5.up.railway.app"

-- Lấy HWID (Hardware ID)
local function getHWID()
    return game:GetService("RbxAnalyticsService"):GetClientId()
end

-- Verify key với API (MongoDB)
local function verifyKey(key)
    local hwid = getHWID()
    
    local success, result = pcall(function()
        local response = request({
            Url = API_URL .. "/api/verify",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                key = key,
                hwid = hwid
            })
        })
        
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success and result then
        return result.success, result.message
    end
    
    return false, "Connection error"
end

-- Main check
local key = getgenv().CheckKey

if not key or key == "" then
    warn("❌ Please set getgenv().CheckKey first!")
    warn("Example: getgenv().CheckKey = 'YOUR_KEY_HERE'")
    return false
end

print("⏳ Verifying key: " .. key)
print("🔐 HWID: " .. getHWID())

local success, message = verifyKey(key)

if success then
    print("✅ Key verified! Access granted.")
    print("📝 Message: " .. message)
    return true
else
    warn("❌ Key verification failed!")
    warn("📝 Reason: " .. message)
    return false
end
