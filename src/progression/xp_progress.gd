class_name XpProgress
extends RefCounted
## Shared XP curve + fill math for units and the selection-panel portrait ring.
##
## Level N→N+1 needs `BASE_XP * GROWTH^(N-1)` XP. Each level costs more than the last.
## Level-up rewards are applied by HunterUpgradeProgression + Unit (CP-21), not here.

const BASE_XP := 100.0
const GROWTH := 1.35


static func xp_to_next(level: int) -> float:
	var safe_level := maxi(level, 1)
	return BASE_XP * pow(GROWTH, float(safe_level - 1))


static func fill_ratio(level: int, xp: float) -> float:
	var need := xp_to_next(level)
	if need <= 0.0:
		return 1.0
	return clampf(xp / need, 0.0, 1.0)


## Applies `amount` XP with overflow level-ups. Returns `{ "level": int, "xp": float }`.
static func apply_gain(level: int, xp: float, amount: float) -> Dictionary:
	var next_level := maxi(level, 1)
	var next_xp := maxf(xp, 0.0)
	var remaining := maxf(amount, 0.0)
	while remaining > 0.0:
		var need := xp_to_next(next_level)
		var space := need - next_xp
		if remaining < space:
			next_xp += remaining
			remaining = 0.0
			break
		remaining -= space
		next_level += 1
		next_xp = 0.0
	return {"level": next_level, "xp": next_xp}
