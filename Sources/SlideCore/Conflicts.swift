/// Other menu bar managers move the same items, and two movers fight over positions.
public enum Conflicts {
    public static let known: [String: String] = [
        "com.surteesstudios.Bartender": "Bartender",
        "com.surteesstudios.Bartender-setapp": "Bartender",
        "com.jordanbaird.Ice": "Ice",
        "com.stonerl.Thaw": "Thaw",
        "com.dwarvesv.minimalbar": "Hidden Bar",
        "com.mortennn.Dozer": "Dozer",
        "net.matthewpalmer.Vanilla": "Vanilla",
    ]

    /// Names of the known managers among the running bundle identifiers, sorted, without duplicates.
    public static func names(running bundleIDs: [String]) -> [String] {
        Set(bundleIDs.compactMap { known[$0] }).sorted()
    }
}
