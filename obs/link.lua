local _note_name_no_brackets = "(([^%]%[]+)[|#]?([^%]%[]+))"
local _note_name_pattern = "%[%[" .. _note_name_no_brackets .. "%]%]"

---Simple link representation
---@class obs.Link
---@field public name string
---@field public alias string?
---@field public header string?
local Link = {}
Link.__index = Link

--- link constructor
---@param name string
---@param alias string?
---@param header string?
---@return obs.Link
function Link:new(name, alias, header)
    return setmetatable({
        name = name,
        alias = alias,
        header = header,
    }, self)
end

---extracts links from the text
---@param text string
---@return obs.Link[]
function Link.from_text(text)
    ---@type obs.Link[]
    local links = {}
    for match in string.gmatch(text, _note_name_pattern) do
        local link = Link.from_string(match)
        table.insert(links, link)
    end
    return links
end

local function split_on_index(to_split, index)
    local before = string.sub(to_split, 1, index - 1)
    local after = string.sub(to_split, index + 1, -1)
    return before, after
end

--- creates link from string like name, name|alias, name#title
---@param str string
---@return obs.Link?
function Link.from_string(str)
    if not string.match(str, "^" .. _note_name_no_brackets .. "$") then
        return nil
    end
    if #str == 0 then
        return nil
    end

    local sharp_index = string.find(str, "#")
    if sharp_index then
        local name, header = split_on_index(str, sharp_index)
        return Link:new(name, nil, header)
    end

    local pipe_index = string.find(str, "|")
    if pipe_index then
        local name, alias = split_on_index(str, pipe_index)
        return Link:new(name, alias, nil)
    end

    return Link:new(str)
end

---Searches for the link under the specified charater
---@param str string string to search in
---@param index number number of the cheracter to search the link around
---@return obs.Link? name of the link
function Link.find_link_at(str, index)
    if #str < 4 then
        return nil
    end

    local start
    local ending
    for i = 2, #str do
        local last_items = string.sub(str, i - 1, i)
        if last_items == "[[" then
            start = i + 1
        end
        if last_items == "]]" then
            ending = i - 2
        end
        if start ~= nil and ending ~= nil then
            if start <= index and ending >= index then
                local link_string = string.sub(str, start, ending)
                return Link.from_string(link_string)
            end
        end
    end
end

return Link
