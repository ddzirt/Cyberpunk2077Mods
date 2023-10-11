module zImmersiveBalance.Config

// ImmersiveBalance ver 1.0
public class IBConfig {
    // Progression is 1 AP and 1 PP for 3 levels(Hard)
    // or 1 AP every 2 levels and capping at 40 with 1 PP for 3 levels.(Easy)
    // Probably reconsider PP for easy
    let isSoft: Bool = false;

    // Set the number of perk points to be obtained on level up
	let perkPointGranted: Int32 = 1;
	
    // Limit perk point award by level in Skill Progression
	let perkPointLevelLimit: Int32 = 3;
}