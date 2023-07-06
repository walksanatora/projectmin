--#region setup

function print(...)
    for _, k in pairs({ ... }) do
        write(k)
        write(" ")
    end
    write("\n")
end

function write(...)
    local first = true
    local log = fs.open("log.txt", "a")
    local line = ""
    for _, thing in pairs({ ... }) do
        if first then
            line = line .. tostring(thing)
        else
            line = line .. " " .. tostring(thing)
        end
    end
    log.write(line)
    log.close()
end

local main = "/src/startup.lua"
print("sized", term.getSize())
local base = fs.getDir(main)
package.path = package.path .. ";/Luz/?.lua;/" .. base .. "/?.lua;/" .. base .. "/?"
print(package.path)
local lcompress = require("Luz.compress")
local llex = require("Luz.lex")

local canload = pcall(load, "")

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function string.split(str, sep)
    if not sep then
        sep = "%s"
    end
    local t = {}
    for part in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(t, part)
    end
    return t
end

local flag_ignore_luz = 0
local regions = 0
--#endregion

--#region WARNING CHATGPT CODE
local function extractRequireString(luaCode)
    local pattern = 'require[%( ]%s*["\']([^"\']+)["\']%s*%)?'
    local requireString = string.match(luaCode, pattern)
    return requireString
end

local function replaceFileExtension(fileName)
    local newFileName, extension = fileName:gsub(".lua$", "")
    newFileName = newFileName .. ".luz"
    return newFileName
end
--#endregion

function build_dep_tree(target)
    local requires = {}
    print("opening", target)
    local file = fs.open(target, 'r')
    if not file then error("failed to open " .. target) end
    while true do
        local line = file.readLine()
        if not line then
            file.close()
            break
        end
        if line:starts("--#region") then
            regions = regions + 1
            if line:match("LUZ:IGNORE") and (flag_ignore_luz == 0) then
                flag_ignore_luz = regions
            end
        elseif line:starts("--#endregion") then
            regions = regions - 1
            if regions <= flag_ignore_luz then
                flag_ignore_luz = 0
            end
        end
        local req = extractRequireString(line)
        if req and not (req:starts("cc%.")) then
            local exempt = flag_ignore_luz ~= 0
            local path = package.searchpath(req, package.path)
            if not (path or ""):starts("/rom") then
                if not requires[req] then
                    requires[req] = {
                        luz = flag_ignore_luz == 0,
                        path = package.searchpath(req, package.path)
                    }
                elseif exempt then
                    requires[req].luz = false
                end
                local subtree = build_dep_tree(requires[req].path)
                for mod, cfg in pairs(subtree) do
                    if not requires[mod] then
                        requires[mod] = cfg
                    elseif not cfg.luz then
                        requires[mod].luz = false
                    end
                end
            end
        end
    end
    return requires
end

local deps = build_dep_tree(main)
print(textutils.serialise(deps))
for mod, cfg in pairs(deps) do
    local source = package.searchpath(mod, package.path)
    local compress = cfg.luz
    local output = "/exported/" .. table.concat(mod:split(), "/") .. ".lua"

    if compress then
        output = replaceFileExtension(output)
    end
    print(mod, compress, source, output)
    local src = fs.open(source or "", 'r')
    if src and compress then
        local data = src.readAll()
        src.close()
        if data then
            local res = ((canload and load or loadstring)(data))
            if res then
                local tokens = llex(data, 1, 2)
                local compressed = lcompress(tokens, 9)
                local file2 = fs.open(output, "wb")
                if file2 then
                    file2.write(compressed)
                    file2.close()
                end
            end
        end
    else
        if not compress and source then
            local res = "/exported/" .. fs.getName(source)
            if fs.exists(res) then fs.delete(res) end
            fs.copy(source, res)
        else
            printError("file is not visible, assumming it is within rom")
            printError(compress, source)
        end
    end
end

local res = "/exported/" .. fs.getName(main)
if fs.exists(res) then fs.delete(res) end
fs.copy(main, res)
os.shutdown()
