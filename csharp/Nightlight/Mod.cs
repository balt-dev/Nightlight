using GDWeave;

namespace Nightlight;

public class Mod : IMod {
    public Mod(IModInterface modInterface) {
        modInterface.RegisterScriptMod(new NightlightScriptMod());
    }

    public void Dispose() {}
}
