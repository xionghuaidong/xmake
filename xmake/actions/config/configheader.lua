--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2017, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        configheader.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.project.project")

-- make configure for the given target name
function _make_for_target(target)

    -- get the target configure file 
    local configheader = target:configheader()
    if not configheader then return end

    -- get the config prefix
    local configprefix = target:configprefix()

    -- open the file
    local file = _g.configfiles[configheader] or io.open(path.join(os.tmpdir(), hash.uuid(configheader)), "w")

    -- make the head
    if _g.configfiles[configheader] then file:print("") end
    file:print("#ifndef %s_H", configprefix)
    file:print("#define %s_H", configprefix)
    file:print("")

    -- make version
    local version, version_build = project.version()
    if version then
        file:print("// version")
        file:print("#define %s_VERSION \"%s\"", configprefix, version)
        local i = 1
        local m = {"MAJOR", "MINOR", "ALTER"}
        for v in version:gmatch("%d+") do
            file:print("#define %s_VERSION_%s %s", configprefix, m[i], v)
            i = i + 1
            if i > 3 then break end
        end
        if version_build then
            file:print("#define %s_VERSION_BUILD %s", configprefix, version_build)
        end
        file:print("")
    end

    -- make the defines
    local defines = table.copy(target:get("defines_h")) 

    -- make the undefines
    local undefines = table.copy(target:get("undefines_h")) 

    -- make the options
    for _, opt in ipairs(target:options()) do

        -- get the option defines
        table.join2(defines, opt:get("defines_h")) 
        table.join2(defines, opt:get("defines_h_if_ok")) -- deprecated 

        -- get the option undefines
        table.join2(undefines, opt:get("undefines_h")) 
        table.join2(undefines, opt:get("undefines_h_if_ok")) -- deprecated
    end

    -- make the defines
    if #defines ~= 0 then
        file:print("// defines")
        for _, define in ipairs(defines) do
            if define:find("=") then
                file:print("#define %s", define:gsub("=", " "):gsub("%$%((.-)%)", function (w) if w == "prefix" then return configprefix end end))
            else
                file:print("#define %s 1", define:gsub("%$%((.-)%)", function (w) if w == "prefix" then return configprefix end end))
            end
        end
        file:print("")
    end

    -- make the undefines 
    if #undefines ~= 0 then
        file:print("// undefines")
        for _, undefine in ipairs(undefines) do
            file:print("#undef %s", undefine:gsub("%$%((.-)%)", function (w) if w == "prefix" then return configprefix end end))
        end
        file:print("")
    end

    -- make the tail
    file:print("#endif")

    -- cache the file
    _g.configfiles[configheader] = file
end

-- make the configure file for the given target and dependents
function _make_for_target_with_deps(targetname)

    -- the target
    local target = project.target(targetname)

    -- make configure for the target
    _make_for_target(target)
     
    -- make configure for the dependent targets?
    for _, dep in ipairs(target:get("deps")) do
        _make_for_target_with_deps(dep)
    end
end

-- make the config.h
function make()

    -- the target name
    local targetname = option.get("target")

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- make configure for the given target name
    _g.configfiles  = {}
    _g.configpathes = {}
    if targetname then
        _make_for_target_with_deps(targetname)
    else
        -- make configure for all targets
        for _, target in pairs(project.targets()) do
            _make_for_target(target)
        end
    end

    -- close and update files
    for configpath, configfile_tmp in pairs(_g.configfiles) do

        -- close the temporary file first
        configfile_tmp:close()

        -- update file if the content is changed
        local configpath_tmp = path.join(os.tmpdir(), hash.uuid(configpath))
        if os.isfile(configpath_tmp) then
            if os.isfile(configpath) then
                if io.readfile(configpath_tmp) ~= io.readfile(configpath) then
                    os.cp(configpath_tmp, configpath)
                end
            else
                os.cp(configpath_tmp, configpath)
            end
        end
    end
 
    -- leave project directory
    os.cd(oldir)
end
