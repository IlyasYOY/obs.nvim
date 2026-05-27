local _note_name_no_brackets = "([^%]%[]+)"
local _note_name_pattern = "%[%[" .. _note_name_no_brackets .. "%]%]"

---Simple link representation
---@class obs.Link
---@field public name string
---@field public alias string?
---@field public header string?
local Link = {}
Link.__index = Link

---@class obs.LinkSpan
---@field public type "wiki"|"markdown"|"url"
---@field public start_col number zero-based inclusive start column
---@field public end_col number zero-based inclusive end column
---@field public cursor_col number zero-based cursor landing column
---@field public link obs.Link?
---@field public text string?
---@field public target string?

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

---@param spans obs.LinkSpan[]
---@param span obs.LinkSpan
local function insert_span(spans, span)
    table.insert(spans, span)
end

---@param str string
---@param spans obs.LinkSpan[]
local function find_wiki_spans(str, spans)
    local init = 1

    while init <= #str do
        local start_pos, end_pos, link_text =
            string.find(str, _note_name_pattern, init)

        if start_pos == nil or end_pos == nil or link_text == nil then
            return
        end

        local link = Link.from_string(link_text)
        if link then
            insert_span(spans, {
                type = "wiki",
                start_col = start_pos - 1,
                end_col = end_pos - 1,
                cursor_col = start_pos + 1,
                link = link,
                text = link_text,
            })
        end

        init = end_pos + 1
    end
end

---@param str string
---@param spans obs.LinkSpan[]
local function find_markdown_spans(str, spans)
    local init = 1

    while init <= #str do
        local start_pos, end_pos, label, target =
            string.find(str, "%[([^%]]+)%]%(([^%)]+)%)", init)

        if start_pos == nil or end_pos == nil then
            return
        end

        insert_span(spans, {
            type = "markdown",
            start_col = start_pos - 1,
            end_col = end_pos - 1,
            cursor_col = start_pos,
            text = label,
            target = target,
        })

        init = end_pos + 1
    end
end

---@param char string
---@return boolean
local function is_url_trailing_punctuation(char)
    return char == "."
        or char == ","
        or char == ";"
        or char == ":"
        or char == "!"
        or char == "?"
        or char == ")"
        or char == "]"
        or char == "}"
end

---@param start_col number zero-based inclusive start column
---@param end_col number zero-based inclusive end column
---@param spans obs.LinkSpan[]
---@return boolean
local function overlaps_existing_span(start_col, end_col, spans)
    for _, span in ipairs(spans) do
        if start_col <= span.end_col and end_col >= span.start_col then
            return true
        end
    end

    return false
end

---@param str string
---@param init number
---@return number?, number?
local function find_next_url_start(str, init)
    local http_start, http_end = string.find(str, "http://", init, true)
    local https_start, https_end = string.find(str, "https://", init, true)

    if http_start == nil then
        return https_start, https_end
    end
    if https_start == nil then
        return http_start, http_end
    end
    if https_start < http_start then
        return https_start, https_end
    end

    return http_start, http_end
end

---@param str string
---@param spans obs.LinkSpan[]
local function find_url_spans(str, spans)
    local init = 1

    while init <= #str do
        local start_pos, scheme_end = find_next_url_start(str, init)

        if start_pos == nil or scheme_end == nil then
            return
        end

        local end_pos = string.find(str, "%s", scheme_end + 1)
        if end_pos == nil then
            end_pos = #str
        else
            end_pos = end_pos - 1
        end

        while
            end_pos >= scheme_end
            and is_url_trailing_punctuation(string.sub(str, end_pos, end_pos))
        do
            end_pos = end_pos - 1
        end

        local start_col = start_pos - 1
        local end_col = end_pos - 1
        if
            end_col >= start_col
            and not overlaps_existing_span(start_col, end_col, spans)
        then
            insert_span(spans, {
                type = "url",
                start_col = start_col,
                end_col = end_col,
                cursor_col = start_col,
                text = string.sub(str, start_pos, end_pos),
                target = string.sub(str, start_pos, end_pos),
            })
        end

        init = math.max(end_pos + 2, scheme_end + 1)
    end
end

---Finds link locations in a single line.
---@param str string string to search in
---@param include_markdown boolean? include inline Markdown links
---@return obs.LinkSpan[]
function Link.find_links_in_line(str, include_markdown)
    ---@type obs.LinkSpan[]
    local spans = {}

    find_wiki_spans(str, spans)
    if include_markdown then
        find_markdown_spans(str, spans)
        find_url_spans(str, spans)
    end

    table.sort(spans, function(a, b)
        return a.start_col < b.start_col
    end)

    return spans
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
    if
        not string.match(str, "^" .. _note_name_no_brackets .. "$")
        or string.find(str, "[", 1, true)
        or string.find(str, "]", 1, true)
    then
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
