extends Control

var prologue_script = null
var items = {}
var traits = {}
var player = {}
var current_scene = {}
var current_scene_idx = 0
var current_prompt_idx = 0
var current_prompt = ""
var current_choices = []
var player_text_format = "Hit Points: {}/10\nMental State: {}\nFitness: {}\nTenacity: {}\nAcuity: {}\nUncanny: {}\nFortune: {}"
var inventory_text_format = "Food: {}\nWater: {}\nInventory:\n{}\nTraits:\n{}\n"
var prompt_timer := Timer.new()
var skipped_prompt_typing = false
var is_loading = true

# Initialize nodes
@onready var SceneImage := get_node("Panel/HBoxContainer/VBoxContainer/SceneImageTexRect")
@onready var PromptText := get_node("Panel/HBoxContainer/VBoxContainer/PromptTextArea")
@onready var ChoiceList := get_node("Panel/HBoxContainer/VBoxContainer/ScrollContainer/ChoiceContainer")
@onready var PlayerText := get_node("Panel/StatButton/PlayerTextArea")
@onready var InventoryText := get_node("Panel/InvButton/InventoryTextArea")
@onready var EffectText := get_node("Panel/EffectTextArea")
@onready var ScreenAnimPlayer := get_node("ScreenAnimationPlayer")
@onready var EffectAnimPlayer := get_node("EffectAnimationPlayer")
@onready var BackgroundAudio1 := get_node("BackgroundAudioStream1")
@onready var BackgroundAudio2 := get_node("BackgroundAudioStream2")
@onready var BackgroundAudio3 := get_node("BackgroundAudioStream3")
@onready var ButtonAudio := get_node("ButtonAudioStream")
@onready var PromptAudio := get_node("PromptAudioStream")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	read_script()
	
	add_child(prompt_timer)
	prompt_timer.one_shot = true
	prompt_timer.timeout.connect(_stop_prompt_sound)
	
	# Load first scene
	if prologue_script == null:
		print("Script not loaded")
	else:
		BackgroundAudio1.play()
		load_scene(1, 0)
		BackgroundAudio2.play()
	
	# Initialize player
	player = {
		"hp": 10,
		"ms": 0,
		"inv" : [
			"01"
		],
		"trt" : [],
		"fit" : 0,
		"ten" : 0,
		"acu" : 0,
		"unc" : 0,
		"for" : 0,
		"fod" : 0,
		"wat" : 0,
		"time" : 0
	}
	
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player["hp"] < 1:
		while player["fod"] > 0 && player["wat"] > 0 && player["hp"] < 1:
			player["fod"] -= 1
			player["wat"] -= 1
			player["hp"] += 1
		if player["hp"] < 1:
			end_game()
	elif player["ms"] < -7:
		end_game()
	
	var player_arr = []
	player_arr.append(player["hp"])
	if player["ms"] > 3:
		player_arr.append("jazzed")
	elif player["ms"] > -1 && player["ms"] <= 3:
		player_arr.append("solid")
	elif player["ms"] >= -3 && player["ms"] < 0:
		player_arr.append("downbeat")
	elif player["ms"] < -3:
		player_arr.append("wasted")
	player_arr.append(player["fit"])
	player_arr.append(player["ten"])
	player_arr.append(player["acu"])
	player_arr.append(player["unc"])
	player_arr.append(player["for"])
	
	PlayerText.text = player_text_format.format(player_arr, "{}")
	
	var inv_arr = []
	inv_arr.append(player["fod"])
	inv_arr.append(player["wat"])
	inv_arr.append(get_player_inventory())
	inv_arr.append(get_player_traits())
	
	InventoryText.text = inventory_text_format.format(inv_arr, "{}")

func _input(event):
	if (event is InputEventMouseButton) and event.pressed and is_loading and !skipped_prompt_typing:
		skipped_prompt_typing = true
		PromptText.text = current_prompt
		prompt_timer.stop()
		prompt_timer.emit_signal("timeout")
		
		# Set choices
		if current_choices.size() == 0:
			var prompt = current_scene["prompts"][current_prompt_idx]
			for choice in prompt["choices"]:
				create_choice(choice)
		
		is_loading = false

	pass
	
func _stop_prompt_sound():
	PromptAudio.stop()
	
# Read script from json file
func read_script() -> void:
	var script_file = FileAccess.open("res://doc/prologue.json", FileAccess.READ)
	var script_content = script_file.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(script_content)
	
	if error == OK:
		var data_received = json.data
		if typeof(data_received) == TYPE_DICTIONARY:
			prologue_script = data_received
			
			for item in prologue_script["inventory"]:
				items[item["id"]] = item["name"]
			for trt in prologue_script["traits"]:
				traits[trt["id"]] = trt["name"]
		else:
			print("Unexpected data: ", typeof(data_received))
	else:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
	
	pass

# Load the scene at the given index and the prompt with the given index from that scene
func load_scene(scene_index, prompt_index) -> void:
	PromptText.text = ""
	
	if scene_index == 01 && prompt_index == 01:
		# Initialize player
		player = {
			"hp": 10,
			"ms": 0,
			"inv" : [
				"01"
			],
			"trt" : [],
			"fit" : 0,
			"ten" : 0,
			"acu" : 0,
			"unc" : 0,
			"for" : 0,
			"fod" : 0,
			"wat" : 0,
			"time" : 0
		}
	
	# Set scene image
	var scene = prologue_script["scenes"][scene_index]
	var new_scene = current_scene_idx != scene_index
	current_scene = scene
	current_scene_idx = scene_index
	current_prompt_idx = prompt_index
	var prompt = scene["prompts"][prompt_index]
	if  new_scene:
		ScreenAnimPlayer.play("screen_fade_anim")
		SceneImage.texture = load("res://img/" + scene["picture"])
		is_loading = true
		await get_tree().create_timer(1.75).timeout
	is_loading = true
	
	await get_tree().create_timer(0.25).timeout
	
	# Set prompt text
	current_prompt = prompt["text"]
	PromptText.text = "[type delay=1.0 speed=50.0]" + current_prompt
	if current_prompt != "" :
		PromptAudio.play()
		var time = current_prompt.length() * 0.0202
		prompt_timer.wait_time = time
		prompt_timer.start()
		await prompt_timer.timeout
		
	await get_tree().create_timer(0.25).timeout
	
	if skipped_prompt_typing:
		is_loading = false
		skipped_prompt_typing = false;
		return
	
	# Set choices
	for choice in prompt["choices"]:
		create_choice(choice)
	
	is_loading = false
	pass

func end_game() -> void:
	PlayerText.text = ""
	
	# Set scene image
	var scene = prologue_script["scenes"][0]
	current_scene = scene
	current_scene_idx = 0
	current_prompt_idx = 0
	BackgroundAudio1.stop()
	BackgroundAudio2.stop()
	BackgroundAudio3.play()
	ScreenAnimPlayer.play("screen_fade_anim")
	SceneImage.texture = load("res://img/" + scene["picture"])
	await get_tree().create_timer(1.75).timeout
	
	var prompt = scene["prompts"][0]
	PromptText.text = ""
	await get_tree().create_timer(0.25).timeout
	
	# Set prompt text
	current_prompt = prompt["text"]
	PromptText.text = "[type delay=1.0 speed=50.0]" + current_prompt
	PromptAudio.play()
	prompt_timer.start()
	await prompt_timer.timeout
	
	await get_tree().create_timer(0.25).timeout
	
	if skipped_prompt_typing:
		skipped_prompt_typing = false
		is_loading = false
		return
	
	# Set choices
	for choice in prompt["choices"]:
		create_choice(choice)
	
func get_player_inventory() -> String:
	var inv_list = ""
	for inv in player["inv"]:
		inv_list = inv_list + items[inv] + "\n"
	return inv_list
	
func get_player_traits() -> String:
	var trt_list = ""
	if player["trt"].size() == 0 :
		return "None\n"
	
	for trt in player["trt"]:
		trt_list = trt_list + traits[trt] + "\n"
	return trt_list
	
func arr_to_str(array) -> String:
	var new_str = ""
	for item in array:
		new_str = new_str + "," + item
	return new_str.substr(1, new_str.length())

func create_choice(choice) -> void:
	var id = choice["id"]
	var text = choice["text"]
	var dest = choice["dest"]
	var effect = ""
	var req = ""
	var mod = ""
	
	if choice.has("effect") :
		effect = choice["effect"]
	
	if choice.has("req") :
		req = choice["req"]
		if !does_player_meet_req(req):
			return
		
	if choice.has("mod") :
		mod = choice["mod"]
	
	var b := Button.new()
	b.pressed.connect(func(): choice_clicked(id))
	b.add_theme_color_override("font_color", Color(0,1,0,1))
	
	if req != "":
		b.add_theme_color_override("font_color", Color(1,1,0,1))
	
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.text = text
	
	ChoiceList.add_child(b)
	
	current_choices.append({
		"id" : id,
		"btn" : b,
		"effect" : effect,
		"dest" : dest,
		"req" : req,
		"mod" : mod
	})
	
	pass
	
func does_player_meet_req(req) -> bool:
	var req_arr = req.split(";", false)
	for single_str in req_arr :
		var req_tag = parse_tag(single_str)
		
		if req_tag == "inv" || req_tag == "trt" :
			var item_arr = single_str.split(":", false)
			if item_arr.size() < 2 :
				print("Invalid effect, skipping.")
				continue
			if player["inv"].find(item_arr[1]) == -1:
				return false
		else :
			var value = 0
			if single_str.contains("+") || single_str.contains("-"):
				value = parse_num(single_str)
			else:
				value = parse_percent(single_str)
			if single_str.contains(">"):
				if value >= player[req_tag]:
					return false
			if single_str.contains("<"):
				if value <= player[req_tag]:
					return false
			if single_str.contains("="):
				if value != player[req_tag]:
					return false
	
	return true

func choice_clicked(id) -> void:
	ButtonAudio.play()
	EffectAnimPlayer.stop(false)
	
	var index = 0
	for i in len(current_choices) :
		if current_choices[i]["id"] == id :
			index = i
			break
				
	var choice = current_choices[index]
	var scene_list = prologue_script["scenes"]
	var prompt_list = current_scene["prompts"]
	var scene_index = 0
	var prompt_index = 0
	
	# Modify player variables
	parse_effect(choice["effect"])
	
	var mod_effect = ""
	if choice["mod"] != "" :
		mod_effect = parse_mod(choice["mod"])
	
	var text = translate_effect_and_mod(choice["effect"], mod_effect)
	EffectAnimPlayer.play("effect_text_anim")
	EffectText.text = text
	
	await get_tree().create_timer(0.25).timeout
	
	# Load new scene / prompt
	var dest = choice["dest"]
	if dest.contains("scn") :
		var scene_id = dest.substr(3)
		for i in len(scene_list) :
			if scene_list[i]["id"] == scene_id :
				scene_index = i
				prompt_index = 0
				break
	elif dest.contains("esc") :
		get_tree().quit()
	else :
		for i in len(prompt_list) :
			if prompt_list[i]["id"] == dest :
				scene_index = current_scene_idx
				prompt_index = i
				break
				
	# Clear old choices
	current_choices = []
	for n in ChoiceList.get_children():
		ChoiceList.remove_child(n)
		n.queue_free() 
	
	load_scene(scene_index, prompt_index)
	
	pass
	
func parse_effect(effect_str) -> void:
	var effect_arr = effect_str.split(";", false)
	
	for single_str in effect_arr :
		var effect_tag = parse_tag(single_str)
		
		if effect_tag == "inv" || effect_tag == "trt":
			var item_arr = single_str.split(":", false)
			if item_arr.size() < 2 :
				print("Invalid effect, skipping.")
				continue
			
			var regex = RegEx.new()
			regex.compile("-")
			var symbol_found = regex.search(item_arr[0])
			
			if symbol_found :
				player[effect_tag].remove_at(player[effect_tag].find(item_arr[1]))
			else :
				player[effect_tag].append(item_arr[1])
		else :
			var effect_num = parse_num(single_str)
			player[effect_tag] += effect_num
	
	pass
	
func parse_mod(mod_str) -> String:
	var mod_return = ""
	var mod_arr = mod_str.split(";", false)
	
	for single_str in mod_arr :	
		var str_arr = single_str.split(">", false)
		if str_arr[0].contains(":"):
			var item_arr = str_arr[0].split(":", false) 
			if player[item_arr[0]].find(item_arr[1]) != -1:
				var tag = parse_tag(str_arr[1])
				var num = parse_num(str_arr[1])
				player[tag] += num
				mod_return = mod_return + str(num) + tag + ";" 
		elif str_arr[0].contains("%"):
			var rng = RandomNumberGenerator.new()
			var my_random_number = rng.randi_range(0, 100)
			var percent = parse_percent(str_arr[0])
			if my_random_number <= percent :
				var tag = parse_tag(str_arr[1])
				var num = parse_num(str_arr[1])
				player[tag] += num
				mod_return = mod_return + str(num) + tag + ";" 
	
	return mod_return
	
func translate_effect_and_mod(effect_str, mod_str) -> String:
	var translation = ""
	
	var effect_arr = effect_str.split(";", false)
	var mod_arr = mod_str.split(";", false)
	
	for effect in effect_arr :	
		if effect.contains(":"):
			var item_arr = effect.split(":", false) 
			if item_arr[0].contains("inv"):
				var item = items[item_arr[1]]
				if effect.contains("+"):
					translation = translation + "Gained: " + item + "\n"
				else :
					translation = translation + "Lost: " + item + "\n"
			if item_arr[0].contains("trt"):
				var trt = traits[item_arr[1]]
				translation = translation + "Gained Trait: " + trt + "\n"
		else :
			var tag = parse_tag(effect)
			var num = parse_num(effect)
			
			for mod in mod_arr :
				var tag_mod = parse_tag(mod)
				var num_mod = parse_num(mod)
				if tag == tag_mod:
					num += num_mod
			
			match tag:
				"time":
					translation = translation + "+" + str(num) + " Time\n"
				"hp":
					if(num > 0) :
						translation = translation + "+" + str(num) + " Hit Points\n"
					else :
						translation = translation + str(num) + " Hit Points\n"
				"ms":
					if(num > 0) :
						translation = translation + "+" + str(num) + " Mental State\n"
					else :
						translation = translation + str(num) + " Mental State\n"
				"fit":
					translation = translation + "+" + str(num) + " Fitness\n"
				"ten":
					translation = translation + "+" + str(num) + " Tenacity\n"
				"acu":
					translation = translation + "+" + str(num) + " Acuity\n"
				"unc":
					translation = translation + "+" + str(num) + " Uncanny\n"
				"for":
					translation = translation + "+" + str(num) + " Fortune\n"
				"fod":
					if(num > 0) :
						translation = translation + "Gained " + str(num) + " Food\n"
					else :
						translation = translation + "Lost " + str(num) + " Food\n"
				"wat":
					if(num > 0) :
						translation = translation + "Gained " + str(num) + " Water\n"
					else :
						translation = translation + "Lost " + str(num) + " Water\n"
	
	return translation
	
func parse_percent(effect_str) -> int:
	var regex = RegEx.new()
	regex.compile("[0-9]")
	var all_numbers_found = regex.search(effect_str)
	return int(all_numbers_found.get_string())
	
func parse_num(effect_str) -> int:
	var regex = RegEx.new()
	regex.compile("[+-][0-9]+")
	var all_numbers_found = regex.search(effect_str)
	return int(all_numbers_found.get_string())
	
func parse_tag(effect_str) -> String:
	var regex = RegEx.new()
	regex.compile("[a-z]+")
	var all_tags_found = regex.search(effect_str)
	return all_tags_found.get_string()
