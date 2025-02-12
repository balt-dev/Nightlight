using GDWeave.Godot;
using GDWeave.Godot.Variants;
using GDWeave.Modding;

namespace Nightlight;

public class NightlightScriptMod : IScriptMod {
    public bool ShouldRun(string path) => path == "res://Scenes/Map/Props/water_main.gdc";

    // returns a list of tokens for the new script, with the input being the original script's tokens
    public IEnumerable<Token> Modify(string path, IEnumerable<Token> tokens) {
        foreach (var token in tokens) {
            yield return token;
        }

        foreach (var token in ScriptTokenizer.Tokenize("""
            onready var Nightlight := $"/root/Nightlight"

            func _physics_process(_delta):
                $main.set_shader_param("out_color", Nightlight.sky_color)
                $main.set_shader_param("depth_color", Nightlight.sky_color.lightened(0.3))
                $main.set_shader_param("foam_color", Nightlight.sky_color.darkened(0.2))
            """)
        ) {
            yield return token;
        }
    }
}
