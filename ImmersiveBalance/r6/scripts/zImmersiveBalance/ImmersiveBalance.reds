// zImmersiveBalance
// by ddz1rt AKA udonSoup
// Version 1.0 for game version 2.0+ with/without PL
// Kudos to rfuzzo and packtojack for initial code snippets and ideas
// Props to PotatoOfDoom for pulter :D

/*
  _____ _   _  ____ _  __  ____  _   _ _____ ___ _   _ 
 |  ___| | | |/ ___| |/ / |  _ \| | | |_   _|_ _| \ | |
 | |_  | | | | |   | ' /  | |_) | | | | | |  | ||  \| |
 |  _| | |_| | |___| . \  |  __/| |_| | | |  | || |\  |
 |_|    \___/ \____|_|\_\ |_|    \___/  |_| |___|_| \_|
                                                        
*/

module udonSoup.zImmersiveBalance

import zImmersiveBalance.Config.IBConfig

// Unused currently
@if(ModuleExists("Codeware"))
import Codeware.UI.*

@if(ModuleExists("SkillsBasedAttributes.reds"))
import SkillsBasedAttributes.reds

@if(ModuleExists("SkillfulAttributes.Config.SBAConfig"))
import SkillsBasedAttributes.Config.SBAConfig

/*
 Perk Points - PP total: 221
 For progressing Skill player can get 10 points.
 For leveling up PP are also granted, same as vanilla 49.
 And with 2.0 came perk shards. Not sure total amount or logic for their spawn.
 But aim is to get 221. Meaning we have to give 30 PP per each of 5 trees.
 So math is ATM: 150 + 49 + 10 = 209, meaning 12 PP missing

 Body:(41)
    4: 6 PP
    9: 5(Shotgun) + 6(Blunt) = 11 PP
    15: 8(Shotgun) + 6(Base) + 6(Blunt) = 20 PP
    20: 4 PP
 Reflexes:(46) 
    4: 6 PP
    9: 5(AR) + 6(Dash) + 6(Blade) = 17 PP
    15: 8(AR) + 5(Base) + 6(Blade) = 19 PP
    20: 4 PP
 Technical:(42)
    4: 4 PP
    9: 6(Nade) + 7(Cyberware) = 13 PP
    15: 8(Nade) + 7(Cyberware) + 7(Tech wep) = 22 PP
    20: 3 PP
 Cool:(45)
    4: 8 PP
    9: 7(Pistol) + 6(Knife) = 13 PP
    15: 7(Pistol) + 7(Sneak) + 7(Knife) = 21 PP
    20: 3 PP
 Intelligence:(47)
    4: 8 PP
    9: 6(NetWatch) + 7(Base) + 5(Smart wep) = 18 PP
    15: 6(NetWatch) + 7(Base) + 5(Smart wep) = 18 PP
    20: 3 PP
*/

// Hook to new game as well, so it works straight away instead
// of loading game to make mod work
@wrapMethod(PlayerDevelopmentData)
public final func OnNewGame() -> Void {
    wrappedMethod();
    // LogChannel(n"DEBUG", s"it works");
    this.SafeProcessStateBasedAttributes();
}

// Hook OnRestored which is called on save load
@wrapMethod(PlayerDevelopmentData)
public final func OnRestored(gameInstance: GameInstance) -> Void {
    wrappedMethod(gameInstance);
    LogChannel(n"DEBUG", s"it works");
    this.SafeProcessStateBasedAttributes();
}

// If there are attributes we proceed if not? Well, IDK why there won't be any.
// Testing showed no need but I'll let it be for now
@addMethod(PlayerDevelopmentData)
private final func SafeProcessStateBasedAttributes() -> Void {
    let attributes: array<SAttribute> = this.GetAttributes();
    if (ArraySize(attributes) <= 0) {
        return;
    }
    if (this.m_owner.IsPlayerControlled()) {
        this.SetPlayerProgression(attributes);
    }
}

// Have to take it from original implementation and reinvent the wheel because otherwise this mod wont work
@addMethod(PlayerDevelopmentData)
private final func GetAttributeIndexNew(type: gamedataStatType, attributes: array<SAttribute>) -> Int32 {
    let i: Int32;
    let attributeType: gamedataStatType;

    i = 0;
    while (i < ArraySize(attributes)) {
        attributeType = attributes[i].attributeName;
        if(Equals(attributeType, type)) {
            return i;
        }
        i += 1;
    }

    return -1;
}

// Calculate Stats for Player Progression and grant Perk Points
@addMethod(PlayerDevelopmentData)
private final func SetPlayerProgression(attributes: array<SAttribute>) -> Void {
    let i: Int32;
    let type: gamedataProficiencyType;
    let attributeType: gamedataStatType;
    let skillLevel: Int32;
    let calculatedAttributeValue: Int32;
    let attIndex: Int32;
    let currentAttributeValue: Int32;
    let IBConfig = new IBConfig();

    // Calculate attribute values
    i = 0;
    // LogChannel(n"DEBUG", s"m_proficiencies: \(ArraySize(this.m_proficiencies))");
    while (i < ArraySize(this.m_proficiencies)) {
        type = this.m_proficiencies[i].type;
        // Filter out wrong types or ones that are no longer in game
        if (Equals(type, gamedataProficiencyType.StrengthSkill) || Equals(type, gamedataProficiencyType.ReflexesSkill) ||
            Equals(type, gamedataProficiencyType.TechnicalAbilitySkill) || Equals(type, gamedataProficiencyType.IntelligenceSkill) ||
            Equals(type, gamedataProficiencyType.CoolSkill)
        ) {           
            skillLevel = this.m_proficiencies[i].currentLevel;
            calculatedAttributeValue = this.CalculateBaseAttribute(skillLevel, IBConfig);

            // TODO: Refactor it somehow because it is eyebleeding
            // And set it for correct Attribute
            if (Equals(type, gamedataProficiencyType.StrengthSkill)) {
                attIndex = this.GetAttributeIndexNew(gamedataStatType.Strength, attributes);
                attributeType = attributes[attIndex].attributeName;
                currentAttributeValue = attributes[attIndex].value;
                if (calculatedAttributeValue != currentAttributeValue) {
                    this.SetAttribute(attributeType, Cast(calculatedAttributeValue));
                }
            } else if (Equals(type, gamedataProficiencyType.ReflexesSkill)) {
                attIndex = this.GetAttributeIndexNew(gamedataStatType.Reflexes, attributes);
                attributeType = attributes[attIndex].attributeName;
                currentAttributeValue = attributes[attIndex].value;
                if (calculatedAttributeValue != currentAttributeValue) {
                    this.SetAttribute(attributeType, Cast(calculatedAttributeValue));
                }
            } else if (Equals(type, gamedataProficiencyType.TechnicalAbilitySkill)) {
                attIndex = this.GetAttributeIndexNew(gamedataStatType.TechnicalAbility, attributes);
                attributeType = attributes[attIndex].attributeName;
                currentAttributeValue = attributes[attIndex].value;
                if (calculatedAttributeValue != currentAttributeValue) {
                    this.SetAttribute(attributeType, Cast(calculatedAttributeValue));
                }
            } else if (Equals(type, gamedataProficiencyType.IntelligenceSkill)) {
                attIndex = this.GetAttributeIndexNew(gamedataStatType.Intelligence, attributes);
                attributeType = attributes[attIndex].attributeName;
                currentAttributeValue = attributes[attIndex].value;
                if (calculatedAttributeValue != currentAttributeValue) {
                    this.SetAttribute(attributeType, Cast(calculatedAttributeValue));
                }
            } else if (Equals(type, gamedataProficiencyType.CoolSkill)) {
                attIndex = this.GetAttributeIndexNew(gamedataStatType.Cool, attributes);
                attributeType = attributes[attIndex].attributeName;
                currentAttributeValue = attributes[attIndex].value;
                if (calculatedAttributeValue != currentAttributeValue) {
                    this.SetAttribute(attributeType, Cast(calculatedAttributeValue));
                }
            }
        }

        i += 1;
    }
}

// Calculate new Attribute Value
@addMethod(PlayerDevelopmentData)
private final func CalculateBaseAttribute(currentSkillValue: Int32, IBConfig: ref<IBConfig>) -> Int32 {
    // Math here can be of 2 ways: Hard or Soft
    // Meaning if we go hard we get attribute point every 3 levels so we max out at 60
    // or soft for 1 attribue for every 2 levels. So we max out at 40
    let returnValue: Int32;
    
    if (currentSkillValue > 0) {
        if (IBConfig.isSoft) {
            if (currentSkillValue <= 40) {
                returnValue = currentSkillValue / 2;
            } else {
                returnValue = 20;
            }
        } else {
            returnValue = currentSkillValue / 3;
        }
    } else { returnValue = 1; }

    return returnValue;
}

// @addMethod(PlayerDevelopmentData)
// private final const func UpdatePerkUI() -> ref<PlayerDevUpdateDataEvent> {
//     LogChannel(n"DEBUG", s"PlayerDevelopmentDataManager UpdateDataNew");
//     let evt: ref<PlayerDevUpdateDataEvent> = new PlayerDevUpdateDataEvent();
//     // evt.GetClassName()
//     return evt;
// }

// As leveling up a proficiency (e.g., skill)
@wrapMethod(PlayerDevelopmentData)
public final const func ModifyProficiencyLevel(type: gamedataProficiencyType, opt isDebug: Bool, opt levelIncrease: Int32) -> Void {
	// Run vanilla code
    wrappedMethod(type, isDebug, levelIncrease);
	
	// Give additional perk points per levels based on config
    let IBConfig = new IBConfig();

    // But first filter out ones that do not belong in this list:
    // [Assault, Athletics, Brawling, ColdBlood, CombatHacking, CoolSkill, Crafting, Demolition, Engineering,
    // Espionage, Gunslinger, Hacking, IntelligenceSkill, Kenjutsu, Level,
    // ReflexesSkill, Stealth, StreetCred, StrengthSkill, TechnicalAbilitySkill, Count, Invalid]

    // It is to be seen if we should keep Level here for 49 PP
    if (Equals(type, gamedataProficiencyType.IntelligenceSkill) || Equals(type, gamedataProficiencyType.ReflexesSkill) ||
        Equals(type, gamedataProficiencyType.StrengthSkill) || Equals(type, gamedataProficiencyType.TechnicalAbilitySkill) ||
        Equals(type, gamedataProficiencyType.CoolSkill) || Equals(type, gamedataProficiencyType.Level)) {
            // Run the stat calculation if it is required
            this.SafeProcessStateBasedAttributes();

            // LogChannel(n"DEBUG", s"type: \(type)");
            let currentLevel = this.m_proficiencies[this.GetProficiencyIndexByType(type)].currentLevel;
            // LogChannel(n"DEBUG", s"currentLevel: \(currentLevel)");
            let check = currentLevel % IBConfig.perkPointLevelLimit == 0;
            // LogChannel(n"DEBUG", s"check: \(check)");
			if (IBConfig.perkPointGranted > 0 && IBConfig.perkPointLevelLimit > 0 && check) {
                // LogChannel(n"DEBUG", s"perk is to be granted!");
				this.AddDevelopmentPoints(IBConfig.perkPointGranted, gamedataDevelopmentPointType.Primary);

                //
                // telemetryEvt.perkPointsAwarded = this.GetDevPointsForLevel(this.m_proficiencies[pIndex].currentLevel, type, gamedataDevelopmentPointType.Primary);

                // And add UI notification here
                // PlayerDevelopmentDataManager.UpdateDataNew();
                // GameInstance.GetUISystem(this.m_owner.GetGame()).QueueEvent( proficiencyProgress );

                // let perkEvent = this.UpdatePerkUI();
                // GameInstance.GetUISystem(this.m_owner.GetGame()).QueueEvent(perkEvent);
			};

            this.updateAttributeLevel(type);
    }
}

@if(ModuleExists("SkillsBasedAttributes.reds"))
@addMethod(PlayerDevelopmentData)
private func updateAttributeLevel(type: gamedataProficiencyType) {
    this.SBAb_updateAttributeLevel(type);
    this.ModifyCyberwareCap(type);
}

@if(!ModuleExists("SkillsBasedAttributes.reds"))
@addMethod(PlayerDevelopmentData)
private func updateAttributeLevel(type: gamedataProficiencyType) {
    // TODO: IDK Figure this out
    // this.SBAb_updateAttributeLevel(type);
    // this.ModifyCyberwareCap(type);
}

// TODO: Figure out to make it work in perk screen UI(locking button instead of allowing animation)
// TODO: Figure out to make it optional
// Turn off ability to buy Attribues
@if(!ModuleExists("SkillsBasedAttributes.reds"))
@replaceMethod(PlayerDevelopmentData)
public final const func CanAttributeBeBought(type: gamedataStatType) -> Bool {
    return false;
}

// // TODO: Figure this out
// @replaceMethod(PlayerDevelopmentData)
// private final const func GetProficiencyMaxLevel(type: gamedataProficiencyType) -> Int32 {
//     let proficiencyRec: ref<Proficiency_Record>;
//     proficiencyRec = RPGManager.GetProficiencyRecord(type);
//     return proficiencyRec.MaxLevel();
// }

@wrapMethod(PlayerDevelopmentData)
public final const func AddDevelopmentPoints(amount: Int32, type: gamedataDevelopmentPointType) -> Void {
	if Equals(type, gamedataDevelopmentPointType.Attribute) {
		return;
	} else {
		wrappedMethod(amount, type);
	};
}

// TODO: Remove button when mod is active
// TODO: Figure out to make it optional
// Turn off ability to reset Attributes
@if(!ModuleExists("SkillsBasedAttributes.reds"))
@replaceMethod(PlayerDevelopmentData)
public final const func ResetAttribute(type: gamedataStatType) -> Void {
	return;
}

// TODO: Not working
// Add UI fix(show 0 Attribute points to spend)
@replaceMethod(PerksMainGameController)
private final const func UpdateAvailablePoints() -> Void {
    LogChannel(n"DEBUG", s"PerksMainGameController UpdateAvailablePoints");
    let investedPerkPoints: Int32;
    let proficiencyType: gamedataProficiencyType;
    switch(this.m_activeScreen) {
        case CharacterScreenType.Attributes:
            // this.m_pointsDisplayController.SetValues(0, this.m_dataManager.GetPerkPoints());
            this.m_pointsDisplayController.SetValues(0, this.m_dataManager.GetPerkPoints());
            this.SetRespecButton(true);
            break;
        case CharacterScreenType.Perks:
            proficiencyType = this.m_perksScreenController.GetProficiencyDisplayData().m_proficiency;
            investedPerkPoints = PlayerDevelopmentSystem.GetData(this.m_dataManager.GetPlayer()).GetInvestedPerkPoints(proficiencyType);
            this.m_pointsDisplayController.SetValues(investedPerkPoints, this.m_dataManager.GetPerkPoints());
            this.SetRespecButton(false);
        break;
    }
}

