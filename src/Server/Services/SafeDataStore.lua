-- Wraps DataStoreService so the game still runs in Studio before the place is
-- published (or with API access off). When the real store is unavailable it
-- falls back to an in-memory store that lasts for the play session only.

local DataStoreService = game:GetService("DataStoreService")

local SafeDataStore = {}

local function NewMock()
    local data = {}
    local mock = {}

    function mock:GetAsync(key) return data[key] end
    function mock:SetAsync(key, value) data[key] = value end
    function mock:RemoveAsync(key) local old = data[key]; data[key] = nil; return old end
    function mock:UpdateAsync(key, fn)
        local new = fn(data[key])
        if new ~= nil then data[key] = new end
        return data[key]
    end
    function mock:GetSortedAsync(ascending, pageSize)
        local list = {}
        for key, value in pairs(data) do
            table.insert(list, { key = key, value = value })
        end
        table.sort(list, function(a, b)
            if ascending then return a.value < b.value end
            return a.value > b.value
        end)
        local page = {}
        for i = 1, math.min(pageSize or 100, #list) do page[i] = list[i] end
        return { GetCurrentPageAsync = function() return page end }
    end

    return mock
end

local function TryGet(getter, name)
    local ok, store = pcall(getter, DataStoreService, name)
    if ok and store then return store end
    warn("[SafeDataStore] '" .. name .. "' unavailable (" .. tostring(store)
        .. ") — using in-memory store; data will NOT persist.")
    return NewMock()
end

function SafeDataStore.GetDataStore(name)
    return TryGet(DataStoreService.GetDataStore, name)
end

function SafeDataStore.GetOrderedDataStore(name)
    return TryGet(DataStoreService.GetOrderedDataStore, name)
end

return SafeDataStore
