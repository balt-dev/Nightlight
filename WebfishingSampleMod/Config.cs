using System.Text.Json.Serialization;

namespace WebfishingSampleMod;

public class Config {
    [JsonInclude] public bool SomeSetting = true;
}
