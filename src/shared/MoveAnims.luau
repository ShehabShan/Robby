--!strict
-- Movement animations (T-026c, D-210): the R15 movement kit's KeyframeSequences, uploaded under the owner
-- with `scripts/upload_anims.py`. Pure data + rules; `client/MoveAnimClient` applies them.
-- Crouch tracks are not uploaded (crouch is deferred, D-160). Fall and climb keep the Roblox defaults.

local MoveAnims = {}

MoveAnims.ids = {
	idle = "119712073383561",
	walk = "124847915630152",
	run = "126286010674935",
	jump = "82887745412127",
	land = "77414236063049",
}

-- Folders of the default `Animate` script whose Animation children get the kit ids.
MoveAnims.slots = { "idle", "walk", "run", "jump" }

-- The land track plays only after a real fall (studs/s downward at touchdown), not on small hops.
MoveAnims.landMinFall = 30

function MoveAnims.assetUrl(id: string): string
	return "rbxassetid://" .. id
end

function MoveAnims.shouldLand(fallSpeed: number): boolean
	return fallSpeed == fallSpeed and fallSpeed >= MoveAnims.landMinFall
end

return MoveAnims
