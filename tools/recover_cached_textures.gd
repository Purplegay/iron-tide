extends SceneTree
## Recover only missing PNG sources from the user's existing local import cache.
## Run against a disposable project copy. Never overwrites a source image.

var recovered: Array = []
var failures: Array = []

func _initialize() -> void:
	var output := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use an isolated project with IRON_TIDE_REPORT_DIR.")
		quit(2)
		return
	scan("res://assets")
	var f := FileAccess.open(output.path_join("texture-recovery.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"recovered": recovered, "failures": failures}, "  "))
	f.close()
	print("Recovered=", recovered.size(), " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)

func scan(directory: String) -> void:
	for child in DirAccess.get_directories_at(directory):
		scan(directory.path_join(child))
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".png.import"):
			continue
		var metadata := directory.path_join(file)
		var source := metadata.trim_suffix(".import")
		if FileAccess.file_exists(source):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(metadata) != OK:
			failures.append(metadata)
			continue
		var cached := str(cfg.get_value("remap", "path", ""))
		var texture = ResourceLoader.load(cached) if not cached.is_empty() else null
		if texture == null or not texture is Texture2D:
			failures.append({"source": source, "cache": cached})
			continue
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			failures.append(source)
			continue
		if image.is_compressed() and image.decompress() != OK:
			failures.append(source)
			continue
		if image.save_png(source) != OK:
			failures.append(source)
			continue
		var roundtrip := Image.load_from_file(ProjectSettings.globalize_path(source))
		roundtrip.convert(image.get_format())
		if roundtrip.get_size() != image.get_size() or roundtrip.get_data() != image.get_data():
			failures.append({"source": source, "reason": "pixel round-trip mismatch"})
			continue
		recovered.append({"source": source, "cache": cached, "width": image.get_width(), "height": image.get_height(),
			"png_sha256": FileAccess.get_sha256(source)})
