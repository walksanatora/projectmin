--#region setup
if true then
    print("Headless enabled")
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
end

function string.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

print("checking existence of /export")
if not fs.exists("exported") then
    fs.makeDir("exported")
end
print("checking existance of /export/luzd.lua")
if not fs.exists("/exported/luzd.lua") then
    -- luz decompressor does not exist, gotta include it
    local decompress = fs.open("Luz/decompress.lua", "r")
    local data = decompress.readAll()
    decompress.close()
    script_lines = string.split(data, "\n")
    local d_tree = fs.open("Luz/token_decode_tree.lua", "r")
    local data_tree = d_tree.readAll()
    d_tree.close()
    script_lines[1] = 'local token_decode_tree = [=[' .. data_tree .. ']=]'
    local out = fs.open("exported/luzd.lua", "w")
    out.write(table.concat(script_lines, "\n"))
    out.close()
end

local main = "/Luz/luz.lua"

local base = fs.getDir(main) .. "/lib"
package.path = package.path .. ";/Luz/?.lua;/" .. base .. "/?.lua;/" .. base .. "/?"
local lcompress = require("Luz.compress")
local llex = require("Luz.lex")

local canload = pcall(load, "")

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
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
    local script = ""
    print("opening", target)
    local file = fs.open(target, 'r')
    if not file then error("failed to open " .. target) end
    while true do
        local line = file.readLine()
        if not line then
            file.close()
            break
        end
        if line:starts("--") then
            if line:starts("--#region") then
                regions = regions + 1
                if line:match("LUZ:IGNORE") and (flag_ignore_luz == 0) then
                    flag_ignore_luz = regions
                end
                script = script .. "\n" .. line
            elseif line:starts("--#endregion") then
                regions = regions - 1
                if regions <= flag_ignore_luz then
                    flag_ignore_luz = 0
                end
                script = script .. "\n" .. line
            elseif line:match("LUZ:REQUIRE") then
                script = script .. [=[
local decompressor = require("luzd")
table.insert(
    package.loaders,
    function(sName)
        local sPath, sErr = package.searchpath(sName, package.path)
        if not sPath then return nil, sErr end
        local module = fs.open(sPath, 'rb')
        if not module then
            return nil, "couldn't open path, *somehow* was removed inbetween now and searchpath"
        end
        local code = module.readAll()
        module.close()
        local success, result = pcall(decompressor, code)
        if not success or not result then
            return nil, result
        end
        local data, err = load(result, "@" .. sPath, nil, _ENV)
        if data then
            return data, sPath
        else
            return nil, err
        end
    end)
    local ppath = {}
    for str in string.gmatch(package.path, "([^;]+)") do
        table.insert(ppath, str)
    end
    for _,pth in ipairs(ppath) do
        if pth:match("%.lua$") then
            local v = {pth:gsub("%.lua$",".luz")}
            table.insert(
                ppath,
                v[1]
            )
        end
    end
    package.path = table.concat(ppath,";")
]=]
            else
                script = script .. "\n" .. line
            end
        else
            script = script .. "\n" .. line
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
    return requires, script
end

local deps, final = build_dep_tree(main)
print("dependicies table")
print(textutils.serialise(deps))
print("name\tluz_compressed\tsource\tdest")
function __main()
    for mod, cfg in pairs(deps) do
        local source = package.searchpath(mod, package.path)
        local compress = cfg.luz
        local output = "/exported/" .. table.concat(mod:split(), "/") .. ".lua"

        if compress then
            output = replaceFileExtension(output)
        end
        print(mod .. "\t" .. tostring(compress) .. "\t" .. source .. "\t" .. output)
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
end

__main()
local res = "/exported/" .. fs.getName(main)
if fs.exists(res) then fs.delete(res) end
local s = fs.open(res, "w")
s.write(final)
s.close()
--fs.copy(main, res)
if _HEADLESS then
    os.shutdown()
end
