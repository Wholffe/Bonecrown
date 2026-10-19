extends GutTest

const DATA_ROOT: String = "res://scripts/data"

var _resources: Array[Resource] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var resource: Resource = load(path)
		assert_not_null(resource, "%s must load" % path)
		_resources.append(resource)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


func test_data_files_exist() -> void:
	assert_gt(_resources.size(), 0, "No .tres files found under %s" % DATA_ROOT)


func test_ids_are_set_and_unique() -> void:
	var seen_ids: Array[StringName] = []
	for resource: Resource in _resources:
		if not "id" in resource:
			continue
		var id: StringName = resource.get("id")
		assert_ne(id, &"", "%s has no id" % resource.resource_path)
		assert_does_not_have(seen_ids, id, "Duplicate id %s" % id)
		seen_ids.append(id)


func test_classes_have_starting_equipment() -> void:
	for resource: Resource in _resources:
		if resource is ClassData:
			var class_data: ClassData = resource
			assert_not_null(class_data.starting_weapon, "%s needs a weapon" % class_data.id)
			assert_not_null(class_data.starting_armor, "%s needs armor" % class_data.id)


func test_weapons_have_valid_damage_dice() -> void:
	for resource: Resource in _resources:
		if resource is WeaponData:
			var weapon: WeaponData = resource
			assert_gt(weapon.damage_die_count, 0, "%s die count" % weapon.id)
			assert_gt(weapon.damage_die_sides, 0, "%s die sides" % weapon.id)


func test_enemies_have_valid_damage_dice_and_hit_points() -> void:
	for resource: Resource in _resources:
		if resource is EnemyData:
			var enemy: EnemyData = resource
			assert_gt(enemy.damage_die_count, 0, "%s die count" % enemy.id)
			assert_gt(enemy.damage_die_sides, 0, "%s die sides" % enemy.id)
			assert_gt(enemy.max_hit_points, 0, "%s hit points" % enemy.id)
