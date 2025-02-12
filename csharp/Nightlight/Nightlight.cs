using GDWeave.Godot;
using GDWeave.Godot.Variants;
using GDWeave.Modding;

namespace Nightlight;

public class NightlightScriptMod : IScriptMod {
    public bool ShouldRun(string path) => path == "res://Scenes/Map/Props/water_main.gdc";

    // returns a list of tokens for the new script, with the input being the original script's tokens
    public IEnumerable<Token> Modify(string path, IEnumerable<Token> tokens) {
        var waiter = new MultiTokenWaiter([
            t => t is IdentifierToken {Name: "_ready"},
            t => t.Type is TokenType.Newline
        ], allowPartialMatch: true);

        foreach (var token in ScriptTokenizer.Tokenize("""
            var mat: ShaderMaterial
            """)
        ) yield return token;
        yield return new Token(TokenType.Newline, 0);

        foreach (var token in tokens) {
            yield return token;

            if (waiter.Check(token)) {
                foreach (var tok in ScriptTokenizer.Tokenize("""
                    mat = $main.get_surface_material(0)
                    """, 1)
                ) yield return tok;

                yield return token;
            }
        }

        foreach (var token in ScriptTokenizer.Tokenize("""
            onready var Nightlight := $"/root/Nightlight"

            func _physics_process(_delta):
                $main.set_shader_param("albedo2", Nightlight.sky_color)
                $main.set_shader_param("albedo", Nightlight.sky_color.lightened(0.3))
                $main.set_shader_param("color_deep", Nightlight.sky_color.darkened(0.8))
                $main.set_shader_param("upper_wave_color", Nightlight.sky_color.darkened(0.8))
                
                $main.set_shader_param("out_color", Nightlight.sky_color)
                $main.set_shader_param("depth_color", Nightlight.sky_color.lightened(0.3))
                $main.set_shader_param("foam_color", Nightlight.sky_color.darkened(0.2))
            """)
        ) yield return token;

        yield return new Token(TokenType.Newline, 0);
    }
}
