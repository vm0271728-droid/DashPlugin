extends RefCounted
class_name PlayerInventory

const SLOT_COUNT := 36
const HOTBAR_SIZE := 9
const MAX_STACK := 64

var slots: Array[Vector2i] = []

func _init() -> void:
    slots.resize(SLOT_COUNT)
    for i in SLOT_COUNT:
        slots[i] = Vector2i.ZERO

func add_item(item_id: int, count: int) -> int:
    if item_id <= 0 or count <= 0:
        return count
    var remaining := count
    for i in SLOT_COUNT:
        var stack := slots[i]
        if stack.x == item_id and stack.y < MAX_STACK:
            var moved := mini(MAX_STACK - stack.y, remaining)
            slots[i] = Vector2i(item_id, stack.y + moved)
            remaining -= moved
            if remaining <= 0:
                return 0
    for i in SLOT_COUNT:
        if slots[i].y <= 0:
            var moved := mini(MAX_STACK, remaining)
            slots[i] = Vector2i(item_id, moved)
            remaining -= moved
            if remaining <= 0:
                return 0
    return remaining

func consume_slot(slot_index: int, count: int = 1) -> bool:
    if slot_index < 0 or slot_index >= SLOT_COUNT or count <= 0:
        return false
    var stack := slots[slot_index]
    if stack.y < count:
        return false
    stack.y -= count
    if stack.y <= 0:
        stack = Vector2i.ZERO
    slots[slot_index] = stack
    return true

func get_slot(slot_index: int) -> Vector2i:
    if slot_index < 0 or slot_index >= SLOT_COUNT:
        return Vector2i.ZERO
    return slots[slot_index]

func hotbar_snapshot() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for i in HOTBAR_SIZE:
        result.append(slots[i])
    return result
