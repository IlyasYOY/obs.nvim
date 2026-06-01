---Tag parsing helpers for Obsidian-style Markdown notes.
local Tag = {}

---@param value string
---@return string
local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param value string
---@return string
local function strip_quotes(value)
    value = trim(value)
    local first = string.sub(value, 1, 1)
    local last = string.sub(value, -1)
    if #value >= 2 and first == last and (first == '"' or first == "'") then
        return string.sub(value, 2, -2)
    end

    return value
end

---@param value string?
---@return string?
local function normalize_tag(value)
    if value == nil then
        return nil
    end

    value = strip_quotes(value)
    while string.sub(value, 1, 1) == "#" do
        value = string.sub(value, 2)
    end
    value = trim(value)

    if value == "" then
        return nil
    end

    return value
end

---@param tags string[]
---@param seen table<string, boolean>
---@param value string?
local function insert_tag(tags, seen, value)
    local tag = normalize_tag(value)
    if tag == nil or seen[tag] then
        return
    end

    seen[tag] = true
    table.insert(tags, tag)
end

---@param tags string[]
---@param seen table<string, boolean>
---@param value string
local function parse_yaml_array(tags, seen, value)
    local inner = string.match(value, "^%[(.*)%]$")
    if inner == nil then
        return
    end

    for item in string.gmatch(inner, "[^,]+") do
        insert_tag(tags, seen, item)
    end
end

---@param tags string[]
---@param seen table<string, boolean>
---@param value string
local function parse_yaml_scalar(tags, seen, value)
    value = string.gsub(value, ",", " ")
    for item in string.gmatch(value, "%S+") do
        insert_tag(tags, seen, item)
    end
end

---@param line string
---@return string
local function strip_cr(line)
    return (line:gsub("\r$", ""))
end

---@param text string
---@return string[]
local function split_lines(text)
    local lines = vim.split(text, "\n", { plain = true })
    for index, line in ipairs(lines) do
        lines[index] = strip_cr(line)
    end

    return lines
end

---@param lines string[]
---@return string[]?, number?
local function frontmatter_lines(lines)
    if lines[1] ~= "---" then
        return nil, nil
    end

    for index = 2, #lines do
        if lines[index] == "---" then
            return vim.list_slice(lines, 2, index - 1), index
        end
    end

    return nil, nil
end

---@param tags string[]
---@param seen table<string, boolean>
---@param lines string[]
local function parse_frontmatter_tags(tags, seen, lines)
    local in_tags_block = false

    for _, line in ipairs(lines) do
        local inline_value = string.match(line, "^%s*tags:%s*(.-)%s*$")
        if inline_value ~= nil then
            in_tags_block = inline_value == ""
            if inline_value ~= "" then
                if string.match(inline_value, "^%[.*%]$") then
                    parse_yaml_array(tags, seen, inline_value)
                else
                    parse_yaml_scalar(tags, seen, inline_value)
                end
            end
        elseif in_tags_block then
            local item = string.match(line, "^%s*%-%s*(.-)%s*$")
            if item ~= nil then
                insert_tag(tags, seen, item)
            elseif trim(line) ~= "" then
                in_tags_block = false
            end
        end
    end
end

---@param char string
---@return boolean
local function is_tag_char(char)
    return string.match(char, "[%w_/%-]") ~= nil
end

---@param char string
---@return boolean
local function is_tag_start_char(char)
    return string.match(char, "[%w_]") ~= nil
end

---@class obs.TagIgnoredSpan
---@field start_pos number one-based inclusive start position
---@field end_pos number one-based inclusive end position

---@param text string
---@return obs.TagIgnoredSpan[]
local function bracket_spans(text)
    local spans = {}
    local start_pos

    for index = 1, #text do
        local char = string.sub(text, index, index)
        if char == "[" and start_pos == nil then
            start_pos = index
        elseif char == "]" and start_pos ~= nil then
            table.insert(spans, {
                start_pos = start_pos,
                end_pos = index,
            })
            start_pos = nil
        end
    end

    return spans
end

---@param line string
---@return string?, number?
local function fence_info(line)
    local marker = string.match(line, "^%s*(```+)")
    if marker ~= nil then
        return "`", #marker
    end

    marker = string.match(line, "^%s*(~~~+)")
    if marker ~= nil then
        return "~", #marker
    end
end

---@param line string
---@param fence_char string
---@param fence_length number
---@return boolean
local function is_closing_fence(line, fence_char, fence_length)
    local marker
    if fence_char == "`" then
        marker = string.match(line, "^%s*(```+)")
    else
        marker = string.match(line, "^%s*(~~~+)")
    end

    return marker ~= nil and #marker >= fence_length
end

---@param text string
---@return obs.TagIgnoredSpan[]
local function fenced_code_spans(text)
    local spans = {}
    local in_fence = false
    local fence_start
    local fence_char
    local fence_length
    local line_start = 1

    while line_start <= #text do
        local newline_start = string.find(text, "\n", line_start, true)
        local line_end = newline_start and newline_start - 1 or #text
        local line = string.sub(text, line_start, line_end)

        if not in_fence then
            fence_char, fence_length = fence_info(line)
            if fence_char ~= nil then
                in_fence = true
                fence_start = line_start
            end
        elseif is_closing_fence(line, fence_char, fence_length) then
            table.insert(spans, {
                start_pos = fence_start,
                end_pos = line_end,
            })
            in_fence = false
            fence_start = nil
            fence_char = nil
            fence_length = nil
        end

        if newline_start == nil then
            break
        end
        line_start = newline_start + 1
    end

    if in_fence then
        table.insert(spans, {
            start_pos = fence_start,
            end_pos = #text,
        })
    end

    return spans
end

---@param text string
---@return obs.TagIgnoredSpan[]
local function ignored_spans(text)
    local spans = bracket_spans(text)
    for _, span in ipairs(fenced_code_spans(text)) do
        table.insert(spans, span)
    end

    return spans
end

---@param position number
---@param spans obs.TagIgnoredSpan[]
---@return boolean
local function is_inside_ignored_span(position, spans)
    for _, span in ipairs(spans) do
        if position >= span.start_pos and position <= span.end_pos then
            return true
        end
    end

    return false
end

---@param text string
---@param tags string[]
---@param seen table<string, boolean>
local function parse_body_tags(text, tags, seen)
    local index = 1
    local spans = ignored_spans(text)

    while index <= #text do
        local sharp = string.find(text, "#", index, true)
        if sharp == nil then
            return
        end

        local previous = sharp == 1 and ""
            or string.sub(text, sharp - 1, sharp - 1)
        local first = string.sub(text, sharp + 1, sharp + 1)
        if
            (previous == "" or not is_tag_char(previous))
            and not is_inside_ignored_span(sharp, spans)
            and is_tag_start_char(first)
        then
            local ending = sharp + 1
            while
                ending <= #text
                and is_tag_char(string.sub(text, ending, ending))
            do
                ending = ending + 1
            end
            insert_tag(tags, seen, string.sub(text, sharp + 1, ending - 1))
            index = ending
        else
            index = sharp + 1
        end
    end
end

---Extracts normalized tags from note text.
---@param text string?
---@return string[]
function Tag.from_text(text)
    if text == nil or text == "" then
        return {}
    end

    local tags = {}
    local seen = {}
    local lines = split_lines(text)
    local yaml_lines, closing_line = frontmatter_lines(lines)
    local body = text

    if yaml_lines ~= nil and closing_line ~= nil then
        parse_frontmatter_tags(tags, seen, yaml_lines)
        body = table.concat(vim.list_slice(lines, closing_line + 1), "\n")
    end

    parse_body_tags(body, tags, seen)

    return tags
end

return Tag
