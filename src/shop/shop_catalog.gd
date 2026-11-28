class_name ShopCatalog
extends RefCounted
## Fixed Hunter shop items (Crystal spend → StatModifier). Runner catalog empty in v1.

const ITEMS: Array[Dictionary] = [
	{
		"id": "shop_max_health",
		"stat": StatBlock.Stat.MAX_HEALTH,
		"value": 25.0,
		"percent": false,
		"cost": 40.0,
	},
	{
		"id": "shop_hp_regen",
		"stat": StatBlock.Stat.HEALTH_REGENERATION,
		"value": 1.0,
		"percent": false,
		"cost": 35.0,
	},
	{
		"id": "shop_defense",
		"stat": StatBlock.Stat.DEFENSE,
		"value": 4.0,
		"percent": false,
		"cost": 35.0,
	},
	{
		"id": "shop_move",
		"stat": StatBlock.Stat.MOVEMENT_SPEED,
		"value": 0.05,
		"percent": true,
		"cost": 45.0,
	},
	{
		"id": "shop_melee",
		"stat": StatBlock.Stat.MELEE_DAMAGE,
		"value": 0.08,
		"percent": true,
		"cost": 50.0,
	},
	{
		"id": "shop_attack_speed",
		"stat": StatBlock.Stat.ATTACK_SPEED,
		"value": 0.06,
		"percent": true,
		"cost": 45.0,
	},
	{
		"id": "shop_crit",
		"stat": StatBlock.Stat.CRITICAL_CHANCE,
		"value": 0.03,
		"percent": false,
		"cost": 40.0,
	},
	{
		"id": "shop_lifesteal",
		"stat": StatBlock.Stat.LIFESTEAL_CHANCE,
		"value": 0.03,
		"percent": false,
		"cost": 40.0,
	},
]


static func items_for_role(role: int) -> Array[Dictionary]:
	if role != RoleConfig.Role.HUNTER:
		return []
	return ITEMS.duplicate(true)


static func item_by_id(item_id: String) -> Dictionary:
	for entry in ITEMS:
		if str(entry.get("id", "")) == item_id:
			return entry
	return {}


static func format_bonus(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var stat: int = int(entry.get("stat", 0))
	var value := float(entry.get("value", 0.0))
	var percent := bool(entry.get("percent", false))
	if percent or stat == StatBlock.Stat.CRITICAL_CHANCE or stat == StatBlock.Stat.LIFESTEAL_CHANCE \
			or stat == StatBlock.Stat.LUCK:
		return "+%s%% %s" % [StatIcons.short_number(value * 100.0), StatIcons.display_name(stat)]
	return "+%s %s" % [StatIcons.short_number(value), StatIcons.display_name(stat)]


static func make_modifier(entry: Dictionary) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = int(entry.get("stat", 0))
	modifier.value = float(entry.get("value", 0.0))
	modifier.kind = StatModifier.Kind.PERCENT if bool(entry.get("percent", false)) \
			else StatModifier.Kind.FLAT
	var item_id := str(entry.get("id", ""))
	if not item_id.is_empty():
		modifier.source = "shop:%s" % item_id
	return modifier
