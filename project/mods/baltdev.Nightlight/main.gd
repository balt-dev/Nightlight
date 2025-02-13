extends Node

var is_halloween: bool

func approximate_sun_position(latitude: float, longitude: float) -> Dictionary:
	var lat = deg2rad(latitude)
	
	var now = Time.get_datetime_dict_from_system(true)
	var year = now["year"]
	var month = now["month"]
	var day = now["day"]
	var hour = now["hour"]
	var minute = now["minute"]
	var second = now["second"]
	
	is_halloween = month == 10 and day == 31
	
	var day_of_year = calculate_day_of_year(year, month, day)	
	second += fmod(Time.get_unix_time_from_system(), 1.0)
	
	var time_decimal = (hour + minute / 60.0 + second / 3600.0)
	time_decimal *= config.time_scale
	time_decimal = fmod(time_decimal, 24)
	day_of_year += time_decimal / 24.0
	
	var ahr = deg2rad((time_decimal - 12.0) * 15.0 + longitude)

	var dec = deg2rad(23.45 * sin(deg2rad(360.0 * (day_of_year - 81) / 365.0)))
	
	var sin_alt = clamp(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ahr), -1, 1)
	var alt = asin(sin_alt)
	
	var cos_azi = clamp((sin(dec) * cos(lat) - cos(dec) * sin(lat) * cos(ahr)) / cos(alt), -1, 1)
	var azi = acos(cos_azi)
	
	if sin(ahr) > 0:
		azi = 2 * PI - azi

	return {"altitude": alt, "azimuth": azi}

func calculate_day_of_year(year: int, month: int, day: int) -> int:
	var days_in_month = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if is_leap_year(year):
		days_in_month[2] = 29

	var day_of_year = 0
	for i in range(1, month):
		day_of_year += days_in_month[i]
	day_of_year += day
	return day_of_year

func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

var moon_color: Color
var night_color: Color
var dawn_color: Color
var sunrise_color: Color
var day_color: Color

const HALLOWEEN_NIGHT_COLOR: Color = Color(0.1, 0.04, 0.02)
const HALLOWEEN_MOON_COLOR: Color = Color(0.4, 0, 0)

func approximate_skylight_color(altitude : float) -> Color:
	var night = night_color
	if is_halloween:
		night = HALLOWEEN_NIGHT_COLOR
	if altitude < -5:
		var twilight_factor = clamp(-(5 + max(altitude, - 10)) / 5.0, 0.0, 1.0)
		return dawn_color.linear_interpolate(night, twilight_factor)
	elif altitude < 0:
		var sunrise_factor = clamp(-altitude / 5.0, 0.0, 1.0)
		return sunrise_color.linear_interpolate(dawn_color, sunrise_factor)
	elif altitude < 15:
		var day_factor = clamp(altitude / 15.0, 0.0, 1.0)
		return sunrise_color.linear_interpolate(day_color, day_factor)
	else:
		return day_color

var worldenv: WorldEnvironment
var dirlight: DirectionalLight
var camera: Camera
var sun: Sprite3D

func _physics_process(_delta):
	if camera == null || !is_instance_valid(camera):
		camera = get_viewport().get_camera()
		
	if worldenv == null || !is_instance_valid(worldenv):
		var world_viewport = get_tree().get_nodes_in_group("world_viewport")
		if world_viewport.empty(): return
		
		var env = world_viewport[0].get_node_or_null("./main/map/main_map/WorldEnvironment")
		
		if env != null && is_instance_valid(env):
			worldenv = env
		else:
			return

		
	if dirlight == null || !is_instance_valid(dirlight):
		var world_viewport = get_tree().get_nodes_in_group("world_viewport")
		if world_viewport.empty(): return
		
		var dli = world_viewport[0].get_node_or_null("./main/map/main_map/WorldEnvironment/DirectionalLight")
					
		if dli != null && is_instance_valid(dli):
			dirlight = dli
		else:
			return
		
	if (sun == null || !is_instance_valid(sun)) && dirlight != null && is_instance_valid(dirlight):
		sun = SUN_SCENE.instance()
		sun.name = "a deadly lazer"
		sun.translation = Vector3(0, 0, 2000)
		dirlight.add_child(sun, true)
			
	var wenv = worldenv.environment
	wenv.fog_enabled = false

	wenv.ambient_light_energy = 0.3

	dirlight.light_negative = false

	var sky_position = approximate_sun_position(config.latitude, config.longitude)
	var color = approximate_skylight_color(rad2deg(sky_position.altitude))
	
	if worldenv.rain:
		sun.opacity = 0.1
		var grey = color.get_luminance()
		color = color.linear_interpolate(Color(grey,grey,grey), 0.9).darkened(0.25)
	
	var degalt = rad2deg(sky_position.altitude)
	if degalt > -9:
		dirlight.rotation.x = -sky_position.altitude
		dirlight.rotation.y = -sky_position.azimuth
		dirlight.light_energy = clamp((rad2deg(sky_position.altitude) + 9) / 5, 0, 1)
		dirlight.light_color = color
		sun.visible = true		
	else:
		dirlight.rotation.x = sky_position.altitude
		dirlight.rotation.y = sky_position.azimuth		
		dirlight.light_energy = clamp((-9 - rad2deg(sky_position.altitude)) / 5, 0, 1)
		var moon = moon_color
		if is_halloween:
			moon = HALLOWEEN_MOON_COLOR
		dirlight.light_color = moon
		sun.visible = false		
	
	worldenv.des_color = color
	wenv.ambient_light_color = color.lightened(config.ambient_color_brightness)
	if is_halloween and degalt < -9:
		var spookiness = clamp((-9 - rad2deg(sky_position.altitude)) / 5, 0, 1)
		worldenv.des_color *= Color.white.linear_interpolate(Color(1.0, 0.2, 0.2), spookiness)
		wenv.ambient_light_color *= Color.white.linear_interpolate(Color(1.0, 0.2, 0.2), spookiness)
	wenv.tonemap_mode = Environment.TONE_MAPPER_ACES
	wenv.tonemap_exposure = 1.12

var config: Dictionary = {}
var default_config: Dictionary = {
	"latitude": 40,
	"longitude": -90,
	"time_scale": 1,
	"moon_color_r": 0.2, "moon_color_g": 0.3, "moon_color_b": 0.5,
	"night_color_r": 0.05, "night_color_g": 0.1, "night_color_b": 0.2,
	"dawn_color_r": 0.1, "dawn_color_g": 0.2, "dawn_color_b": 0.4,
	"sunrise_color_r": 0.8, "sunrise_color_g": 0.3, "sunrise_color_b": 0.1,
	"day_color_r": 0.8, "day_color_g": 0.95, "day_color_b": 1,
	"ambient_color_brightness": 0.1
}

onready var TackleBox := $"/root/TackleBox"

const MOD_ID: String = "baltdev.Nightlight"
const SUN_SCENE: PackedScene = preload("res://mods/baltdev.Nightlight/sun.tscn")

func _ready() -> void:
	_init_config()
	TackleBox.connect("mod_config_updated", self, "_on_config_update")

func _init_config() -> void:
	var saved_config = TackleBox.get_mod_config(MOD_ID)

	for key in default_config.keys():
		if not key in saved_config: # If the config property isn't saved...
			saved_config[key] = default_config[key] # Set it to the default
	
	config = saved_config
	update_colors()
	TackleBox.set_mod_config(MOD_ID, config) # Save it to a config file!

func _on_config_update(mod_id, new_config):
	if mod_id != MOD_ID: # Check if it's our mod being updated
		return
	
	if config.hash() == new_config.hash(): # Check if the config is different
		return
	
	config = new_config # Set the local config variable to the updated config
	update_colors()

func update_colors():
	moon_color = Color(config.moon_color_r, config.moon_color_g, config.moon_color_b)
	night_color = Color(config.night_color_r, config.night_color_g, config.night_color_b)
	dawn_color = Color(config.dawn_color_r, config.dawn_color_g, config.dawn_color_b)
	sunrise_color = Color(config.sunrise_color_r, config.sunrise_color_g, config.sunrise_color_b)
	day_color = Color(config.day_color_r, config.day_color_g, config.day_color_b)
