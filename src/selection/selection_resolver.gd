class_name SelectionResolver
extends RefCounted
## Picks one clickable entity from a candidate list using controls.README.md §1.1 priority.


enum Tier {
	OWN = 0,
	PLAYER = 1,
	NPC = 2,
}


static func pick(candidates: Array, local_peer_id: int, rng: RandomNumberGenerator = null) -> Node:
	if candidates.is_empty():
		return null
	var own: Array = []
	var players: Array = []
	var npcs: Array = []
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not is_visible_to_local(candidate):
			continue
		match _tier(candidate, local_peer_id):
			Tier.OWN:
				own.append(candidate)
			Tier.PLAYER:
				players.append(candidate)
			_:
				npcs.append(candidate)
	if not own.is_empty():
		return _pick_random(own, rng)
	if not players.is_empty():
		return _pick_random(players, rng)
	if not npcs.is_empty():
		return _pick_random(npcs, rng)
	return null


## Fog of war: entities the local team cannot currently see are not clickable
## (docs/vision.README.md). True when there is no VisionSystem or the node is not fogged.
static func is_visible_to_local(candidate: Object) -> bool:
	if candidate is Node:
		return VisionPresentation.can_local_see(candidate as Node)
	return true


static func _tier(candidate: Object, local_peer_id: int) -> Tier:
	if candidate.has_method("is_local_controllable") and bool(candidate.call("is_local_controllable", local_peer_id)):
		return Tier.OWN
	## Owned structures (Buildings use is_own / owner_peer_id, not peer_id).
	if candidate.has_method("is_own") and bool(candidate.call("is_own", local_peer_id)):
		return Tier.OWN
	if candidate.get("peer_id") != null and int(candidate.get("peer_id")) == local_peer_id:
		return Tier.OWN
	if candidate.has_method("is_player_character") and bool(candidate.call("is_player_character")):
		return Tier.PLAYER
	return Tier.NPC


static func _pick_random(items: Array, rng: RandomNumberGenerator) -> Node:
	if items.size() == 1:
		return items[0] as Node
	var index := 0
	if rng != null:
		index = rng.randi_range(0, items.size() - 1)
	else:
		index = randi() % items.size()
	return items[index] as Node
