--!strict
-- Server snapshots can arrive before Character replication; identity, not attributes,
-- gates input. Higher epochs replace snapshots, duplicates never reset sequences.
local CastReady = {}
export type State = { epoch: number, generation: string?, character: any }
function CastReady.new(): State
	return { epoch = 0, generation = nil, character = nil }
end
function CastReady.receive(s: State, epoch: number, generation: string, character: any): boolean
	if epoch <= s.epoch then
		-- A previously unresolved Instance may become available in a sync reply.
		if epoch == s.epoch and generation == s.generation and s.character == nil then
			s.character = character
		end
		return false
	end
	s.epoch, s.generation, s.character = epoch, generation, character
	return true
end
function CastReady.ready(s: State, character: any): boolean
	return character ~= nil and s.character == character and s.generation ~= nil
end
return CastReady
