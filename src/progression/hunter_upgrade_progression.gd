class_name HunterUpgradeProgression
extends RefCounted
## Server-side Hunter level-up rolls and shared option formatting.

enum Rarity { BASIC, ADVANCED, RARE, LEGENDARY }

const CHOICE_COUNT := 3
const OPTION_STATS: Array[StatBlock.Stat] = [
	StatBlock.Stat.MAX_HEALTH,
	StatBlock.Stat.HEALTH_REGENERATION,
	StatBlock.Stat.DEFENSE,
	StatBlock.Stat.MOVEMENT_SPEED,
	StatBlock.Stat.MELEE_DAMAGE,
	StatBlock.Stat.CRITICAL_CHANCE,
	StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER,
	StatBlock.Stat.LIFESTEAL_CHANCE,
	StatBlock.Stat.LIFESTEAL_AMOUNT,
	StatBlock.Stat.ATTACK_SPEED,
	StatBlock.Stat.LUCK,
]
const STAT_RANGES := {
	StatBlock.Stat.MAX_HEALTH: Vector2(15.0, 35.0),
	StatBlock.Stat.HEALTH_REGENERATION: Vector2(0.5, 1.5),
	StatBlock.Stat.DEFENSE: Vector2(2.0, 5.0),
	StatBlock.Stat.MOVEMENT_SPEED: Vector2(0.02, 0.05),
	StatBlock.Stat.MELEE_DAMAGE: Vector2(0.04, 0.08),
	StatBlock.Stat.CRITICAL_CHANCE: Vector2(0.01, 0.025),
	StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER: Vector2(0.05, 0.15),
	StatBlock.Stat.LIFESTEAL_CHANCE: Vector2(0.01, 0.025),
	StatBlock.Stat.LIFESTEAL_AMOUNT: Vector2(1.0, 3.0),
	StatBlock.Stat.ATTACK_SPEED: Vector2(0.03, 0.06),
	StatBlock.Stat.LUCK: Vector2(0.02, 0.05),
}
const PERCENT_STATS := {
	StatBlock.Stat.MOVEMENT_SPEED: true,
	StatBlock.Stat.MELEE_DAMAGE: true,
	StatBlock.Stat.ATTACK_SPEED: true,
}
const RARITY_MULTIPLIERS := [1.0, 1.5, 2.25, 3.5]
const RARITY_NAMES := ["Basic", "Advanced", "Rare", "Legendary"]
const RARITY_COLORS := [
	Color("#4f8fea"),
	Color("#51c878"),
	Color("#b16bea"),
	Color("#e7ad3d"),
]


static func rarity_weights(luck: float) -> PackedFloat32Array:
	var value := clampf(luck, 0.0, 1.0)
	return PackedFloat32Array([60.0 - 17.0 * value, 27.0, 10.0 + 10.0 * value, 3.0 + 7.0 * value])


static func rarity_for_roll(roll: float, luck: float) -> int:
	var weights := rarity_weights(luck)
	var total := 0.0
	for weight in weights:
		total += weight
	var threshold := clampf(roll, 0.0, 0.999999) * total
	var cumulative := 0.0
	for rarity in weights.size():
		cumulative += weights[rarity]
		if threshold < cumulative:
			return rarity
	return Rarity.LEGENDARY


static func roll_choices(
	luck: float, rng: RandomNumberGenerator = null
) -> Array[Dictionary]:
	var generator: RandomNumberGenerator = rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()
	var available := OPTION_STATS.duplicate()
	var choices: Array[Dictionary] = []
	for _choice in CHOICE_COUNT:
		var stat_index := generator.randi_range(0, available.size() - 1)
		var stat: StatBlock.Stat = available[stat_index]
		available.remove_at(stat_index)
		var rarity := rarity_for_roll(generator.randf(), luck)
		var amount_range := value_range(stat, rarity)
		var value := generator.randf_range(amount_range.x, amount_range.y)
		choices.append({"stat": int(stat), "rarity": rarity, "value": value})
	return choices


static func value_range(stat: StatBlock.Stat, rarity: int) -> Vector2:
	var base_range: Vector2 = STAT_RANGES[stat]
	var multiplier := float(RARITY_MULTIPLIERS[clampi(rarity, 0, Rarity.size() - 1)])
	return base_range * multiplier


static func is_percent_stat(stat: StatBlock.Stat) -> bool:
	return PERCENT_STATS.has(stat)


static func rarity_name(rarity: int) -> String:
	if rarity < 0 or rarity >= RARITY_NAMES.size():
		return RARITY_NAMES[Rarity.BASIC]
	return RARITY_NAMES[rarity]


static func rarity_color(rarity: int) -> Color:
	if rarity < 0 or rarity >= RARITY_COLORS.size():
		return RARITY_COLORS[Rarity.BASIC]
	return RARITY_COLORS[rarity]


static func format_bonus(stat: StatBlock.Stat, value: float) -> String:
	var amount := StatIcons.short_number(value * 100.0) + "%" \
			if is_percent_stat(stat) or stat == StatBlock.Stat.CRITICAL_CHANCE \
			or stat == StatBlock.Stat.LIFESTEAL_CHANCE or stat == StatBlock.Stat.LUCK \
			else StatIcons.short_number(value)
	return "+%s %s" % [amount, StatIcons.display_name(stat)]


static func format_range(stat: StatBlock.Stat, rarity: int) -> String:
	var amount_range := value_range(stat, rarity)
	var minimum := amount_range.x
	var maximum := amount_range.y
	if is_percent_stat(stat) or stat == StatBlock.Stat.CRITICAL_CHANCE \
			or stat == StatBlock.Stat.LIFESTEAL_CHANCE or stat == StatBlock.Stat.LUCK:
		return "%s–%s%%" % [
			StatIcons.short_number(minimum * 100.0),
			StatIcons.short_number(maximum * 100.0),
		]
	return "%s–%s" % [StatIcons.short_number(minimum), StatIcons.short_number(maximum)]
