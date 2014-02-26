//Attemps to fix hitching on repeat material loads.

local PrecacheTextures = {
"materials/infestation/infestation_decal.material",
"cinematics/vfx_materials/heal_marine.material",
"cinematics/vfx_materials/heal_alien.material",
"cinematics/vfx_materials/umbra.material",
"cinematics/vfx_materials/heal_alien_view.material",
"cinematics/vfx_materials/umbra_view.material",
"cinematics/vfx_materials/detected.material",
"cinematics/vfx_materials/cloaked.material",
"cinematics/vfx_materials/heal_marine_view.material",
"cinematics/vfx_materials/decals/bullet_hole_01.material",
"cinematics/vfx_materials/decals/bullet_hole_02.material",
"cinematics/vfx_materials/decals/bullet_hole_03.material",
"cinematics/vfx_materials/decals/bullet_hole_04.material",
"cinematics/vfx_materials/decals/bite_01.material",
"cinematics/vfx_materials/decals/bite_02.material",
"materials/power/powered_decal.material",
"cinematics/vfx_materials/placement_valid.material",
"cinematics/vfx_materials/ghoststructure.material",
"cinematics/vfx_materials/build.material",
"cinematics/vfx_materials/decals/alien_blood_01.material",
"cinematics/vfx_materials/decals/alien_blood_02.material",
"cinematics/vfx_materials/decals/alien_blood_03.material",
"cinematics/vfx_materials/decals/alien_blood_04.material",
"cinematics/vfx_materials/decals/alien_blood_ground.material",
"cinematics/vfx_materials/nanoshield.material",
"cinematics/vfx_materials/nanoshield_view.material",
"cinematics/vfx_materials/decals/marine_blood_01.material",
"cinematics/vfx_materials/decals/marine_blood_02.material",
"cinematics/vfx_materials/decals/marine_blood_03.material",
"cinematics/vfx_materials/decals/marine_blood_04.material",
"cinematics/vfx_materials/decals/clawmark_01.material",
"cinematics/vfx_materials/decals/clawmark_02.material",
"cinematics/vfx_materials/decals/clawmark_03.material",
"cinematics/vfx_materials/decals/clawmark_04.material",
"cinematics/vfx_materials/placement_invalid.material",
"cinematics/vfx_materials/enzyme_view.material",
"cinematics/vfx_materials/enzyme.material",
"cinematics/vfx_materials/decals/shockwave_crack.material",
"cinematics/vfx_materials/decals/shockwave_hit.material",
"cinematics/vfx_materials/decals/bilebomb_decal.material",
"cinematics/vfx_materials/decals/blast_01.material",
"materials/infestation/infestation_decal_simple.material",
"cinematics/vfx_materials/fade_blink.material"
}

local PrecacheAssets = {
"models/alien/infestation/infestation2.model",
"models/alien/infestation/infestation.material",
"models/marine/powerpoint_impulse/powerpoint_impulse.model",
"models/marine/powerpoint_impulse/powerpoint_impulse.material",
"models/marine/rifle/rifle_view_shell.model",
"models/marine/rifle/rifle_shell_01.material",
"models/misc/commander_arrow.model",
"models/misc/waypoint_arrow.material",
"models/effects/frag_metal_01.model",
"models/effects/frag_metal.material",
"models/effects/elec_trails.model",
"models/effects/elec_trails.material",
"models/effects/frag_metal_05.model",
"models/effects/frag_metal_02.model",
"cinematics/alien/build/build.cinematic",
"models/alien/lerk/lerk_view_spike.model",
"models/alien/lerk/lerk_view_spike.material"
}

for i, filename in ipairs(PrecacheAssets) do
	PrecacheAsset(filename)
end

local CachedTextures = { }
local Loaded = false
local modstatus

local function OnFirstUpdateClient()
	if not Loaded then
		Loaded = true
		modstatus = Client.GetOptionBoolean("lowTextures", false)
		if modstatus then
			for i, filename in ipairs(PrecacheTextures) do
				CachedTextures[filename] = Client.CreateRenderMaterial()
				CachedTextures[filename]:SetMaterial(filename)
			end
		end
		Shared.Message([[TextureMod loaded which attempts to reduce the occurance of hitches.  Type "sv_nsltextures" in console to toggle this on/off, may increase memory usage!]])
	end
end

Event.Hook("UpdateClient", OnFirstUpdateClient)

function OnCommandTextureAdjustments()
	if Client then
		Client.SetOptionBoolean("lowTextures", not modstatus)
		modstatus = Client.GetOptionBoolean("lowTextures", false)
		Shared.Message("NSL textures " .. ConditionalValue(modstatus, "enabled", "disabled") .. ".")
	end
end

Event.Hook("Console_sv_nsltextures", OnCommandTextureAdjustments)

local originalRenderMaterialSetMaterial = RenderMaterial.SetMaterial
function RenderMaterial:SetMaterial(filename)
	originalRenderMaterialSetMaterial(self, filename)
	if CachedTextures[filename] == nil and modstatus then
		CachedTextures[filename] = Client.CreateRenderMaterial()
		CachedTextures[filename]:SetMaterial(filename)
		//Shared.Message(string.format("Caching texture %s", filename))
		//The only risk i see for this still allowing textures to unload is if the client goes out of relevancy range of this.
		//But I think thats normally handled via :Destroy on the relevant ent so I think these will still persist, therefore keeping the
		//textures in memory?  I hope :S
	end
end

function OnClientDisconnected()
	//Should clean them up I supose
	for filename, material in pairs(CachedTextures) do
		Client.DestroyRenderMaterial(material)
	end
	CachedTextures = { }
end

Event.Hook("ClientDisconnected", OnClientDisconnected)

function OnCommandPrintCachedTextures()
	for filename, material in pairs(CachedTextures) do
		Shared.Message(filename)
	end
end

Event.Hook("Console_sv_nsllisttextures", OnCommandPrintCachedTextures)