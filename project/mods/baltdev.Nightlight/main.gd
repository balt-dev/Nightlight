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
	
	is_halloween = true # month == 10 and day == 31
	
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

const MOON_COLOR: Color = Color(0.2, 0.3, 0.5)
const NIGHT_COLOR: Color = Color(0.05, 0.1, 0.2)
const DAWN_COLOR: Color = Color(0.1, 0.2, 0.4)
const SUNRISE_COLOR: Color = Color(0.8, 0.3, 0.1)
const DAY_COLOR: Color = Color(0.5, 0.7, 1)

const HALLOWEEN_NIGHT_COLOR: Color = Color(0.1, 0.04, 0.02)
const HALLOWEEN_MOON_COLOR: Color = Color(0.4, 0.0, 0)

func approximate_skylight_color(altitude : float) -> Color:
	var night = NIGHT_COLOR
	if is_halloween:
		night = HALLOWEEN_NIGHT_COLOR
	if altitude < -4:
		var twilight_factor = clamp(-(4 + max(altitude, - 10)) / 6.0, 0.0, 1.0)
		return DAWN_COLOR.linear_interpolate(night, twilight_factor)
	elif altitude < 0:
		var sunrise_factor = clamp(-altitude / 4.0, 0.0, 1.0)
		return SUNRISE_COLOR.linear_interpolate(DAWN_COLOR, sunrise_factor)
	elif altitude < 7:
		var day_factor = clamp(altitude / 7.0, 0.0, 1.0)
		return SUNRISE_COLOR.linear_interpolate(DAY_COLOR, day_factor)
	else:
		return DAY_COLOR

var worldenv: WorldEnvironment;
var dirlight: DirectionalLight;

func _physics_process(_delta):
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
			
	var wenv = worldenv.environment
	wenv.fog_enabled = false

	wenv.ambient_light_energy = 0.3

	dirlight.light_negative = false
	dirlight.shadow_enabled = true

	var sky_position = approximate_sun_position(config.latitude, config.longitude)
	var color = approximate_skylight_color(rad2deg(sky_position.altitude))
	
	if worldenv.rain:
		var grey = color.get_luminance()
		color = color.linear_interpolate(Color(grey,grey,grey), 0.7).darkened(0.25)
	
	var degalt = rad2deg(sky_position.altitude)
	if degalt > -4:
		dirlight.rotation.x = -sky_position.altitude
		dirlight.rotation.y = sky_position.azimuth
		dirlight.light_energy = clamp((rad2deg(sky_position.altitude) + 4) / 5, 0, 1)
		dirlight.light_color = color
	else:
		dirlight.rotation.x = sky_position.altitude
		dirlight.rotation.y = -sky_position.azimuth		
		dirlight.light_energy = clamp((-4 - rad2deg(sky_position.altitude)) / 5, 0, 1)
		var moon = MOON_COLOR
		if is_halloween:
			moon = HALLOWEEN_MOON_COLOR
		dirlight.light_color = MOON_COLOR		
	
	worldenv.des_color = color
	wenv.fog_color = color
	wenv.background_color = color
	wenv.ambient_light_color = color.lightened(0.3)
	wenv.tonemap_mode = Environment.TONE_MAPPER_ACES
	wenv.tonemap_exposure = 1.12

var config: Dictionary
var default_config: Dictionary = {
	"latitude": 40,
	"longitude": -90,
	"time_scale": 2000
}
onready var TackleBox := $"/root/TackleBox"

const MOD_ID: String = "baltdev.Nightlight"

func _ready() -> void:
	_init_config()
	#TackleBox.connect("mod_config_updated", self, "_on_config_update")

func _init_config() -> void:
	var saved_config = {}#TackleBox.get_mod_config(MOD_ID)

	for key in default_config.keys():
		if not key in saved_config: # If the config property isn't saved...
			saved_config[key] = default_config[key] # Set it to the default
	
	config = saved_config
	#TackleBox.set_mod_config(MOD_ID, config) # Save it to a config file!

func _on_config_update(mod_id: String, new_config: Dictionary) -> void:
	if mod_id != MOD_ID: # Check if it's our mod being updated
		return
	
	if config.hash() == new_config.hash(): # Check if the config is different
		return
	
	config = new_config # Set the local config variable to the updated config
