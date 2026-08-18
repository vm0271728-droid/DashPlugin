extends Node
class_name BlockRegistry

var _blocks: Dictionary = {}

func register_block(definition: BlockDefinition) -> void:
    assert(definition != null)
    assert(not _blocks.has(definition.id), "Duplicate block id: %s" % definition.id)
    _blocks[definition.id] = definition

func get_block(id: int) -> BlockDefinition:
    return _blocks.get(id)

func has_block(id: int) -> bool:
    return _blocks.has(id)

func all_blocks() -> Array[BlockDefinition]:
    var out: Array[BlockDefinition] = []
    for value in _blocks.values():
        out.append(value)
    return out
