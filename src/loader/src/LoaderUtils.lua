---
-- @module LoaderUtils
-- @author Quenty

local DEPENDENCY_FOLDER_NAME = "node_modules";

local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)

local LoaderUtils = {}

function LoaderUtils.toWallyFormat(folder, format)
    local versionedPackages = LoaderUtils.getOrCreateFolder(format.Shared, "VersionedPackages")

    LoaderUtils.loadPackages(LoaderUtils.getPackages(folder), format.Shared, versionedPackages, {})
end

function LoaderUtils.getOrCreateFolder(parent, folderName)
    local found = parent:FindFirstChild(folderName)
    if found then
        return found
    else
        local folder = Instance.new("Folder")
        folder.Name = folderName
        folder.Parent = parent
        return folder
    end
end

function LoaderUtils.copyTable(target)
	local new = {}
	for key, value in pairs(target) do
		new[key] = value
	end
	return new
end

function LoaderUtils.loadPackages(startingPackages, startingParent, versionedPackages)
    local dependenciesNeedResolving = {}

    local function loadPackages(packages, parent, initialExplicitAncestorPackages)
        local explicitAncestorPackages = LoaderUtils.copyTable(initialExplicitAncestorPackages)

        for _, package in pairs(packages) do
            local moduleScripts = {}

            for _, moduleScript in pairs(LoaderUtils.getPackageModuleScripts(package)) do
                if parent:FindFirstChild(moduleScript.Name) then
                    error(("[LoaderUtils.loadPackage] - Duplicate instance %q already exists"):format(moduleScript.Name))
                end

                moduleScript.Parent = parent
                table.insert(moduleScripts, moduleScript)
            end

            table.insert(explicitAncestorPackages, {
                package = package;
                moduleScripts = moduleScripts;
            })
            table.insert(dependenciesNeedResolving, {
                parent = parent;
                package = package;
                moduleScripts = moduleScripts;
                explicitAncestorPackages = explicitAncestorPackages;
            })
        end
    end

    -- Load all packages in first
    loadPackages(startingPackages, startingParent, {})

    -- Now resolve dependencies layer-by-layer
    while next(dependenciesNeedResolving) do
        local data = table.remove(dependenciesNeedResolving, 1) -- O(n^2)

        local explicitDependencies = LoaderUtils.getExplicitPackageDependencies(data.package)
        if not LoaderUtils.doDependenciesConflict(data.package, data.parent) then
            -- Safe to leave this package where it is and load all of its descendants in this flat folder
            loadPackages(explicitDependencies, data.parent, data.explicitAncestorPackages)
        else
            -- Link to new package
            local newFolder = LoaderUtils.swapToVersionedPackage(data.package, data.moduleScripts, versionedPackages)

            -- Load up dependencies into the new folder
            loadPackages(explicitDependencies, newFolder, data.explicitAncestorPackages)

            -- Link explicit parent dependencies that weren't conflicting
            for _, packageData in pairs(data.explicitAncestorPackages) do
                for _, moduleScript in pairs(packageData.moduleScript) do
                    if not newFolder:FindFirstChild(moduleScript) then
                        local link = BounceTemplateUtils.create(module)
                        link.Parent = newFolder
                    end
                end
            end
        end
    end
end

function LoaderUtils.swapToVersionedPackage(package, moduleScripts, versionedPackages)
    local folder = Instance.new("Folder")
    folder.Name = package

    for _, module in pairs(moduleScripts) do
        local link = BounceTemplateUtils.create(module)
        link.Parent = module.Parent
        module.Parent = folder
    end

    folder.Parent = versionedPackages
    return folder
end

function LoaderUtils.doDependenciesConflict(package, parent)
    for _, dependentPackage in pairs(LoaderUtils.getExplicitPackageDependencies(package)) do
        for _, moduleScript in pairs(LoaderUtils.getPackageModuleScripts(dependentPackage)) do
            if parent:FindFirstChild(moduleScript.Name) then
                return true
            end
        end
    end

    return false
end

function LoaderUtils.getPackageModuleScripts(package, moduleScripts)
    assert(typeof(package) == "Instance" and package:IsA("Folder"), "Bad folder")

    moduleScripts = moduleScripts or {}

    for _, item in pairs(package:GetChildren()) do
        if item:IsA("Folder") then
            if item.Name ~= DEPENDENCY_FOLDER_NAME then
                LoaderUtils.getPackageModuleScripts(package, moduleScripts)
            end
        elseif item:IsA("ModuleScript") then
            table.insert(moduleScripts, item)
        end
    end

    return moduleScripts
end

function LoaderUtils.getExplicitPackageDependencies(package)
    assert(typeof(package) == "Instance" and package:IsA("package"), "Bad folder")

    local packages = {}

    for _, item in pairs(package:GetChildren()) do
        if item:IsA("Folder") and item.Name == DEPENDENCY_FOLDER_NAME then
            LoaderUtils.getPackages(package, packages)
        end
    end

    return packages
end

function LoaderUtils.getPackages(folder, packages)
    assert(typeof(folder) == "Instance" and folder:IsA("Folder"), "Bad folder")
    packages = packages or {}

    if folder:FindFirstChild(DEPENDENCY_FOLDER_NAME) then
        table.insert(packages, folder)
    else
        for _, item in pairs(folder:GetChildren()) do
            if item:IsA("Folder") then
                LoaderUtils.getPackages(item, packages)
            elseif item:IsA("ObjectValue") then
                -- TODO: Prevent infinite recursion
                local value = item.Value
                if value and value:IsA("Folder") then
                    LoaderUtils.getPackages(value, packages)
                end
            end
        end
    end

    return packages
end

return LoaderUtils