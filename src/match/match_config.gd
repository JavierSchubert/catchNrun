class_name MatchConfig
extends Resource
## Flow values for a match. Edit match_config.tres to change them.

@export var runner_head_start_duration := 60.0 ## Seconds the Runners prepare before the Hunter spawns.
@export var min_players := 2 ## Players needed (host included) before a match can start.
