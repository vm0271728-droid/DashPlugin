extends RefCounted
class_name DefaultBlocks

# Atlas tiles (4x4):
# 0 dirt, 1 grass_top, 2 grass_side, 3 stone,
# 4 sand, 5 log_side, 6 log_top, 7 leaves,
# 8 cobble, 9 coal_ore, 10 iron_ore, 11 planks,
# 12 glass, 13 water, 14 bedrock, 15 gravel.
static func build_registry() -> BlockRegistry:
    var registry := BlockRegistry.new()
    registry.register_block(_make_block(0, "Air", 0, 0, 0, 0.0, true, false, false))
    registry.register_block(_make_block(1, "Dirt", 0, 0, 0, 0.5))
    registry.register_block(_make_block(2, "Grass", 1, 2, 0, 0.6))
    registry.get_block(2).drop_item_id = 1
    registry.register_block(_make_block(3, "Stone", 3, 3, 3, 1.5))
    registry.get_block(3).drop_item_id = 7
    registry.register_block(_make_block(4, "Sand", 4, 4, 4, 0.5, false, true, true, true))
    registry.register_block(_make_block(5, "Oak Log", 6, 5, 6, 2.0))
    registry.register_block(_make_block(6, "Oak Leaves", 7, 7, 7, 0.2, true))
    registry.register_block(_make_block(7, "Cobblestone", 8, 8, 8, 2.0))
    registry.register_block(_make_block(8, "Coal Ore", 9, 9, 9, 3.0))
    registry.register_block(_make_block(9, "Iron Ore", 10, 10, 10, 3.0))
    registry.register_block(_make_block(10, "Oak Planks", 11, 11, 11, 2.0))
    registry.register_block(_make_block(11, "Glass", 12, 12, 12, 0.3, true))
    registry.register_block(_make_block(12, "Water", 13, 13, 13, 100.0, true, false, false))
    registry.register_block(_make_block(13, "Bedrock", 14, 14, 14, -1.0, false, true, false))
    registry.register_block(_make_block(14, "Gravel", 15, 15, 15, 0.6, false, true, true, true))
    return registry

static func _make_block(
        id: int,
        title: String,
        top_tile: int,
        side_tile: int,
        bottom_tile: int,
        hardness: float,
        transparent: bool = false,
        collision: bool = true,
        placeable: bool = true,
        gravity_affected: bool = false
    ) -> BlockDefinition:
    var block := BlockDefinition.new()
    block.id = id
    block.display_name = title
    block.hardness = hardness
    block.transparent = transparent
    block.has_collision = collision
    block.placeable = placeable
    block.gravity_affected = gravity_affected
    block.drop_item_id = id
    block.light_transmission = 15 if transparent else 0
    block.tile_top = top_tile
    block.tile_side = side_tile
    block.tile_bottom = bottom_tile
    return block
