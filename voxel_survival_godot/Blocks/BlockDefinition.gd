extends Resource
class_name BlockDefinition

@export var id: int = 0
@export var display_name: String = ""
@export var hardness: float = 0.0
@export var transparent: bool = false
@export var has_collision: bool = true
@export var placeable: bool = true
@export var gravity_affected: bool = false
@export var drop_item_id: int = 0
@export_range(0, 15, 1) var light_emission: int = 0
@export_range(0, 15, 1) var light_transmission: int = 0
@export var required_tool: StringName = &""
@export var required_tool_level: int = 0
@export var tile_top: int = 0
@export var tile_side: int = 0
@export var tile_bottom: int = 0
@export var albedo_color: Color = Color.WHITE

func tile_for_normal(normal: Vector3) -> int:
    if normal.y > 0.5:
        return tile_top
    if normal.y < -0.5:
        return tile_bottom
    return tile_side
