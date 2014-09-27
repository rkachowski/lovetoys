-- Getting folder that contains engine
local folderOfThisFile = (...):match("(.-)[^%/]+$")

-- Requiring class
require(folderOfThisFile .. "class")

-- Requiring all Events
require(folderOfThisFile .. "events/componentAdded")
require(folderOfThisFile .. "events/componentRemoved")
require(folderOfThisFile .. "events/beginContact")

-- Requiring the lovetoys
require(folderOfThisFile .. "entity")
require(folderOfThisFile .. "system")
require(folderOfThisFile .. "eventManager")
require(folderOfThisFile .. "collisionManager")
require(folderOfThisFile .. "component")


Engine = class("Engine")

function Engine:__init() 
    self.entities = {}
    self.requirements = {}
    self.entityLists = {}
    self.eventManager = EventManager()
    
    self.allSystems = {}
    self.logicSystems = {}
    self.drawSystems = {}
    self.inputSystems = {}
    
    self.allSystemCollections = {self.logicSystems, self.drawSystems, self.inputSystems}
    
    self.freeIds = {}
    self.maxId = 1
    self.eventManager:addListener("ComponentRemoved", {self, self.componentRemoved})
    self.eventManager:addListener("ComponentAdded", {self, self.componentAdded})
end

function Engine:addEntity(entity)
    
    entity.eventManager = self.eventManager
    
    -- Getting the next free ID or insert into table
    if #self.freeIds == 0 then
        entity.id = self.maxId
        self.maxId = self.maxId + 1
        table.insert(self.entities, entity)
    else
        entity.id = table.remove(self.freeIds, #self.freeIds)
        self.entities[entity.id] = entity
    end
    
    for index, component in pairs(entity.components) do
        -- Adding Entity to specific Entitylist
        if not self.entityLists[component.__name] then self.entityLists[component.__name] = {} end
        self.entityLists[component.__name][entity.id] = entity
        
        -- Adding Entity to System if all requirements are granted
        if self.requirements[component.__name] then
            for index2, system in pairs(self.requirements[component.__name]) do
                self:checkRequirements(entity, system)
            end
        end
    end
end 

function Engine:removeEntity(entity)
    -- Stashing the id of the removed Entity in self.freeIds
    table.insert(self.freeIds, entity.id)
    -- Removing the Entity from all Systems and engine
    for i, component in pairs(entity.components) do
        if self.requirements[component.__name] then
            for i2, system in pairs(self.requirements[component.__name]) do
                system:removeEntity(entity)
            end
        end
    end
    -- Deleting the Entity from the specific entity lists
    for index, component in pairs(entity.components) do
        self.entityLists[component.__name][entity.id] = nil
    end
    if self.entities[entity.id] then
        self.entities[entity.id] = nil
    else
        print("Trying to remove non existent entity from engine.")
        print("Entity id: " .. entity.id)
        print("Entity's components:")
        for index, component in pairs(entity.components) do
            print(index)
        end
    end
end

local function addSystemTo(systemCollection, system)
    table.insert(systemCollection, system)
    table.sort(systemCollection, function(a, b) return a.priority < b.priority end)
end

function Engine:addSystem(system, typ, priority)
    if priority then
        system.priority = priority
    end
    for index, value in pairs(self.allSystems) do
        if value.__name == system.__name then
            print("Lovetoys: " .. system.__name .. " already exists. Aborting")
            return
        end
    end
    -- Adding System to draw or logic table
    if typ == "draw" then
        addSystemTo(self.drawSystems, system)
    elseif typ == "logic" then
        addSystemTo(self.logicSystems, system)
    elseif typ == "input" then
        addSystemTo(self.inputSystems, system)
    elseif typ == "all" then
        for _, collection in pairs(self.allSystemCollections) do
            addSystemTo(collection, system)
        end
    end
    
    table.insert(self.allSystems, system)
    
    -- Registering the systems requirements and saving them in a special table for fast access
    for index, value in pairs(system:requires()) do
        if type(value) == "string" then
            self.requirements[value] = self.requirements[value] or {}
            table.insert(self.requirements[value], system)
        elseif type(value) == "table" then
            for index2, string in pairs(value) do
                self.requirements[string] = self.requirements[string] or {}
                table.insert(self.requirements[string], system)
            end
            system.targets[index] = {}
        end
    end
    -- Checks if some of the already entities match the required components.
    for index, entity in pairs(self.entities) do
        self:checkRequirements(entity, system)
    end
    return system
end

function Engine:removeSystem(system)
    
    local requirements
    -- Removes it from the allSystem list
    for k, v in pairs(self.allSystems) do
        if v.__name == system then
            requirements = v:requires()
            table.remove(self.allSystems, k)
        end
    end
    if requirements ~= nil then 
        --  Remove the System from all requirement lists
        for k, v in pairs(requirements) do
            if type(v) == "string" then
                for k2, v2 in pairs(self.requirements[v]) do
                    if v2.__name == system then
                        table.remove(self.requirements, k2)
                    end
                end
                -- Removing if it has subtables
            elseif type(v) == "table" then
                for k2, v2 in pairs(v) do
                    for k3, v3 in pairs(self.requirements[v2]) do
                        if v3.__name == system then
                            table.remove(self.requirements, k3)
                        end
                    end
                end
            end
        end
        
        -- Remove the system from all systemlists
        for _, collection in pairs(self.allSystemCollections) do
            for k, v in pairs(collection)do
                if v.__name == system then
                    table.remove(collection, k)
                end
            end
        end
    else
        print("Lovetoys: " .. system .. " doesn't exist. System can't be removed from engine.")
    end
end

function Engine:update(dt)
    for index, system in ipairs(self.logicSystems) do
        system:update(dt)
    end
end

function Engine:draw()
    for index, system in ipairs(self.drawSystems) do
        system:draw()
    end
end

function Engine:mousepressed(x, y, button)
    for index, system in ipairs(self.inputSystems) do
        if system.mousepressed then
            system:mousepressed(x, y, button)
        end
    end
end

function Engine:mousereleased(x, y, button)
    for index, system in ipairs(self.inputSystems) do
        if system.mousereleased then
            system:mousereleased(x, y, button)
        end
    end
end

function Engine:keypressed(key, isrepeat)
    for index, system in ipairs(self.inputSystems) do
        if system.keypressed then
            system:keypressed(key, isrepeat)
        end
    end
end

function Engine:keyreleased(key)
    for index, system in ipairs(self.inputSystems) do
        if system.keyreleased then
            system:keyreleased(key)
        end
    end
end

function Engine:textinput(text)
    for index, system in ipairs(self.inputSystems) do
        if system.textinput then
            self.engine:textinput(text)
        end
    end
end

function Engine.componentRemoved(self, event)
    local entity = event.entity
    local component = event.component
    -- Removing Entity from Entitylists
    self.entityLists[component][entity.id] = nil
    -- Removing Entity from old systems
    if self.requirements[component] then
        for index, system in pairs(self.requirements[component]) do 
            system:removeEntity(entity)
        end
    end
end

function Engine.componentAdded(self, event)
    local entity = event.entity
    local component = event.component
    -- Adding the Entity to Entitylist
    if not self.entityLists[component] then self.entityLists[component] = {} end
    self.entityLists[component][entity.id] = entity
    -- Adding the Entity to the requiring systems
    if self.requirements[component] then
        for index, system in pairs(self.requirements[component]) do
            self:checkRequirements(entity, system)
        end
    end
end

-- Returns an Entitylist for a specific component. If the Entitylist doesn't exist yet it'll be created and returned.
function Engine:getEntityList(component)
    if not self.entityLists[component] then self.entityLists[component] = {} end
    return self.entityLists[component]
end

function Engine:checkRequirements(entity, system)
    local meetsrequirements = true
    local category = nil
    for index, req in pairs(system.requires()) do
        if type(req) == "string" then
            if not entity.components[req] then
                meetsrequirements = false
                break
            end
        elseif type(req) == "table" then
            meetsrequirements = true
            for index2, req2 in pairs(req) do
                if not entity.components[req2] then
                    meetsrequirements = false
                    break
                end
            end
            if meetsrequirements == true then
                category = index 
                system:addEntity(entity, category)
            end
        end
    end
    if meetsrequirements == true and category == nil then
        system:addEntity(entity)
    end
end

