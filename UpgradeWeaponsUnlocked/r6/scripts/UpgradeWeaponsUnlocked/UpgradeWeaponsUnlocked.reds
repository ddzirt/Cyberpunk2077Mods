/*
 UpgradeWeaponsUnlocked
 by ddz1rt AKA udonSoup
 Version 1.0 for game version 2.0+ with/without PL
 Kudos to packtojack for support and psiberx for `red-hot-reload`
 Props to PotatoOfDoom for pulter :D

  _____ _   _  ____ _  __  ____  _   _ _____ ___ _   _ 
 |  ___| | | |/ ___| |/ / |  _ \| | | |_   _|_ _| \ | |
 | |_  | | | | |   | ' /  | |_) | | | | | |  | ||  \| |
 |  _| | |_| | |___| . \  |  __/| |_| | | |  | || |\  |
 |_|    \___/ \____|_|\_\ |_|    \___/  |_| |___|_| \_|


*/

module udonSoup.UpgradeWeaponsUnlocked

/*
    What I want for game to do:
    on UpdateTooltipData I want to see actual item data
    on GetItemFinalUpgradeCost I want to see actual item data
    on UpgradeItem I want to know what is happening with my item before trying anything

    What do I know about item:
    itemData: ref<gameItemData> <- is what I work with
    
    From here I can:
    let itemQuality: gamedataQuality = RPGManager.GetItemQuality(itemData); // Which shows me Common, Uncommon, ...
    let itemQuality: gamedataQuality = RPGManager.GetItemQuality(1); // Same as above
    let itemQualityNumber: Float = RPGManager.ItemQualityEnumToValue(itemQuality); // 0, 1, 2, 3, 4. 
    let nextItemQuality: gamedataQuality = RPGManager.GetBumpedQuality(itemQuality); // From Common to Uncommon, ...

    // Tries to get info from Item, meaning:
    // GetItemTierForUpgrades(itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded));
    // `WasItemUpgraded` has to contain itemTierQuality value for it to work correctly
    // Which in the end did not worked out so I replaced it in the end. `WasItemUpgraded` is only for UI now
    let itemTierQuality: gamedataQuality = RPGManager.GetItemTierForUpgrades(itemData); // Which shows me Common, CommonPlus
    // Uses direct conversion from Float to Enum
    let itemTierQualityForUpgrade: gamedataQuality = RPGManager.GetItemTierForUpgrades(itemQualityNumber); // Common, CommonPlus
*/

// In 2.0 nonIconic weapons are not upgradeable
// So we add things that allow just that
// However we have to meddle with UI and this onItemAddedToInventory
// TODO: Investigate a way to reduce amount of custom logic. Because it seems totally possible
// in retrospect. At least with less unoptimized code
@addMethod(PlayerPuppet)
public final func SetUsualWeaponsLevelReq(itemData: ref<gameItemData>) -> Void {
    let qualityToUpgradeMod: ref<gameStatModifierData>;
    let upgradeToPlusMod: ref<gameStatModifierData>;
    let upgradeToQualityMod: ref<gameStatModifierData>;
    let iconicCheck: Bool = itemData.HasTag(n"IconicWeapon");

    let itemQuality: gamedataQuality = RPGManager.GetItemQuality(itemData);
    let itemQualityValue: Float = RPGManager.ItemQualityEnumToValue(itemQuality);
    let itemWasUpgraded: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let isPlus: Float = itemData.GetStatValueByType(gamedataStatType.IsItemPlus);
    let newItemUpgraded: Float;
    
    if (Cast<Bool>(isPlus)) {
        newItemUpgraded = itemQualityValue * 2.0 + 1.0; 
    } else { newItemUpgraded = itemQualityValue + 1.0; }

    if (!iconicCheck && (itemWasUpgraded < 1.00)) {
        qualityToUpgradeMod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newItemUpgraded);
        GameInstance.GetStatsSystem(this.GetGame()).RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.WasItemUpgraded, true);
        GameInstance.GetStatsSystem(this.GetGame()).AddSavedModifier(itemData.GetStatsObjectID(), qualityToUpgradeMod);
       
        upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);
        GameInstance.GetStatsSystem(this.GetGame()).RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
        GameInstance.GetStatsSystem(this.GetGame()).AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
              
        upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, isPlus);
        GameInstance.GetStatsSystem(this.GetGame()).RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
        GameInstance.GetStatsSystem(this.GetGame()).AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
    };
}

@replaceMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
    let drawItemRequest: ref<DrawItemRequest>;
    let entryString: String;
    let eqSystem: wref<EquipmentSystem>;
    let itemData: wref<gameItemData>;
    let itemLogDataData: ItemID;
    let itemName: String;
    let itemRecord: ref<Item_Record>;
    let notification_Message: String;
    let player: ref<GameObject>;
    let price: Int32;
    let questSystem: ref<QuestsSystem>;
    let tags: array<CName>;
    let wardrobeSystem: wref<WardrobeSystem> = GameInstance.GetWardrobeSystem(this.GetGame());
    let transSystem: wref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
    let itemQuality: gamedataQuality = gamedataQuality.Invalid;
    let itemCategory: gamedataItemCategory = gamedataItemCategory.Invalid;
    let itemType: gamedataItemType = gamedataItemType.Invalid;
    let weaponEvolution: gamedataWeaponEvolution = gamedataWeaponEvolution.Invalid;

    if (!ItemID.IsValid(evt.itemID)) {
        return false;
    };

    itemData = evt.itemData;
    questSystem = GameInstance.GetQuestsSystem(this.GetGame());
    itemRecord = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(evt.itemID));
    itemCategory = RPGManager.GetItemCategory(evt.itemID);
    itemType = RPGManager.GetItemType(evt.itemID);
    itemLogDataData = evt.itemID;

    if (IsDefined(itemData)) {
        if (!itemRecord.IsSingleInstance()) {
            this.UpdateInventoryWeight(RPGManager.GetItemWeight(itemData), RPGManager.IsItemBroken(itemData));
        };

        this.TryScaleItemToPlayer(itemData);
        if (Equals(itemCategory, gamedataItemCategory.Weapon)) {
            // LogChannel(n"DEBUG", "We run SetUsualWeaponsLevelReq");
            this.SetIconicWeaponsLevelReq(itemData);
            this.SetUsualWeaponsLevelReq(itemData);
        };
        if (Equals(itemCategory, gamedataItemCategory.Cyberware)) {
            if (itemData.HasStatData(gamedataStatType.Airdropped)) {
                player = GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerMainGameObject();
                StatusEffectHelper.ApplyStatusEffect(player, t"BaseStatusEffect.JustLootedIconicCWFromAirdrop");
            };
            if (itemData.HasStatData(gamedataStatType.IconicCWFromTreasureChestLooted)) {
                player = GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerMainGameObject();
                StatusEffectHelper.ApplyStatusEffect(player, t"BaseStatusEffect.JustLootedIconicCWFromTreasureChest");
            };
        };

        itemQuality = RPGManager.GetItemDataQuality(itemData);
        if (!(itemData.HasTag(n"SkipActivityLog") || itemData.HasTag(n"SkipActivityLogOnLoot") ||
              evt.flaggedAsSilent || itemData.HasTag(n"Currency") || ItemID.HasFlag(itemData.GetID(), gameEItemIDFlag.Preview) ||
              (itemData.HasTag(n"QuickhackCraftingMaterials") || itemData.HasTag(n"SoftwareShard") ||
              itemData.HasTag(n"Recipe")) && GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this))) {
                itemName = UIItemsHelper.GetItemName(itemRecord, itemData);
                GameInstance.GetActivityLogSystem(this.GetGame()).AddLog(GetLocalizedText("UI-ScriptExports-Looted") + ": " + itemName);
        };
    };

    if IsDefined(this.m_itemLogBlackboard) {
        this.m_itemLogBlackboard.SetVariant(GetAllBlackboardDefs().UI_ItemLog.ItemLogItem, ToVariant(itemLogDataData), true);
    };

    eqSystem = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
    if (IsDefined(eqSystem)) {
        if (Equals(itemCategory, gamedataItemCategory.Weapon) && IsDefined(itemData) && itemData.HasTag(n"TakeAndEquip")) {
            drawItemRequest = new DrawItemRequest();
            drawItemRequest.owner = this;
            drawItemRequest.itemID = evt.itemID;
            eqSystem.QueueRequest(drawItemRequest);
        };
    };

    if (IsDefined(wardrobeSystem) && Equals(itemCategory, gamedataItemCategory.Clothing) && !wardrobeSystem.IsItemBlacklisted(evt.itemID)) {
        wardrobeSystem.StoreUniqueItemIDAndMarkNew(this.GetGame(), evt.itemID);
    };

    if (Equals(itemType, gamedataItemType.Con_Skillbook)) {
        GameInstance.GetTelemetrySystem(this.GetGame()).LogSkillbookUsed(this, evt.itemID);
        ItemActionsHelper.LearnItem(this, evt.itemID, true);

        if (itemData.HasTag(n"LargeSkillbook")) {
            notification_Message = GetLocalizedText("LocKey#46534") + "\\n";
            if (itemData.HasTag(n"Body")) {
                notification_Message += GetLocalizedText("LocKey#93274");
            } else {
                if (itemData.HasTag(n"Reflex")) {
                    notification_Message += GetLocalizedText("LocKey#93275");
                } else {
                    if (itemData.HasTag(n"Intelligence")) {
                        notification_Message += GetLocalizedText("LocKey#93278");
                    } else {
                        if (itemData.HasTag(n"Cool")) {
                            notification_Message += GetLocalizedText("LocKey#93280");
                        } else {
                            if (itemData.HasTag(n"Tech")) {
                                notification_Message += GetLocalizedText("LocKey#51170");
                            } else {
                                if (itemData.HasTag(n"PerkSkillbook")) {
                                    notification_Message += GetLocalizedText("LocKey#2694");
                                };
                            };
                        };
                    };
                };
            };
        } else {
            notification_Message = GetLocalizedText("LocKey#46534") + "\\n" + GetLocalizedText(LocKeyToString(TweakDBInterface.GetItemRecord(ItemID.GetTDBID(evt.itemID)).LocalizedDescription()));
        };

        this.SetWarningMessage(notification_Message, SimpleMessageType.Neutral);
    } else {
        if (Equals(itemType, gamedataItemType.Con_Edible)) {
            if (itemData.HasTag(n"PermanentFood")) {
                ItemActionsHelper.ConsumeItem(this, evt.itemID, true);
                if (itemData.HasTag(n"PermanentStaminaFood")) {
                    Cast<Int32>(this.GetPermanentFoodBonus(gamedataStatType.StaminaRegenBonusBlackmarket));
                    notification_Message = GetLocalizedText("LocKey#93105") + "\\n" + GetLocalizedText("LocKey#93723");
                } else {
                    if (itemData.HasTag(n"PermanentMemoryFood")) {
                        Cast<Int32>(this.GetPermanentFoodBonus(gamedataStatType.MemoryRegenBonusBlackmarket));
                        notification_Message = GetLocalizedText("LocKey#93106") + "\\n" + GetLocalizedText("LocKey#93724");
                    } else {
                        if (itemData.HasTag(n"PermanentHealthFood")) {
                            Cast<Int32>(this.GetPermanentFoodBonus(gamedataStatType.HealthBonusBlackmarket));
                            notification_Message = GetLocalizedText("LocKey#93104") + "\\n" + GetLocalizedText("LocKey#93725");
                        };
                    };
                };
                this.SetWarningMessage(notification_Message, SimpleMessageType.Neutral);
            };
        } else {
            if (Equals(itemType, gamedataItemType.Gen_Readable)) {
                transSystem.RemoveItem(this, evt.itemID, 1);
                entryString = ReadAction.GetJournalEntryFromAction(ItemActionsHelper.GetReadAction(evt.itemID).GetID());
                GameInstance.GetJournalManager(this.GetGame()).ChangeEntryState(entryString, "gameJournalOnscreen", gameJournalEntryState.Active, JournalNotifyOption.Notify);
            } else {
                if (Equals(itemType, gamedataItemType.Gen_Junk) &&
                    GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatType.CanAutomaticallyDisassembleJunk) > 0.00) {
                    ItemActionsHelper.DisassembleItem(this, evt.itemID, transSystem.GetItemQuantity(this, evt.itemID));
                } else {
                    if (Equals(itemType, gamedataItemType.Gad_Grenade) || Equals(itemType, gamedataItemType.Con_Inhaler) || Equals(itemType, gamedataItemType.Con_Injector)) {
                        tags = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemLogDataData)).Tags();
                        ConsumablesChargesHelper.LeaveTheBestQualityConsumable(this.GetGame(), ConsumablesChargesHelper.GetConsumableTag(tags));
                        ConsumablesChargesHelper.HideConsumableRecipe(this.GetGame(), ItemID.GetTDBID(evt.itemID));
                    } else {
                        if (Equals(itemType, gamedataItemType.Con_Ammo)) {
                            GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UI_EquipmentData).SetBool(GetAllBlackboardDefs().UI_EquipmentData.ammoLooted, true);
                            GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UI_EquipmentData).SignalBool(GetAllBlackboardDefs().UI_EquipmentData.ammoLooted);
                        } else {
                            if (Equals(itemType, gamedataItemType.Gen_Keycard)) {
                                this.GotKeycardNotification();
                            } else {
                                if (Equals(itemType, gamedataItemType.Gen_MoneyShard)) {
                                    price = RPGManager.CalculateSellPrice(this.GetGame(), this, evt.itemID) * evt.itemData.GetQuantity();
                                    transSystem.GiveMoney(this, price, n"money");
                                    transSystem.RemoveItem(this, evt.itemID, transSystem.GetItemQuantity(this, evt.itemID));
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    if (RPGManager.IsItemBroken(evt.itemData) && RPGManager.IsItemWeapon(evt.itemID)) {
        ItemActionsHelper.DisassembleItem(this, evt.itemID, transSystem.GetItemQuantity(this, evt.itemID));
    };

    if (questSystem.GetFact(n"disable_tutorials") == 0 && questSystem.GetFact(n"q001_show_sts_tut") > 0 && !RPGManager.IsItemBroken(evt.itemData)) {
        weaponEvolution = RPGManager.GetWeaponEvolution(evt.itemID);
        if (Equals(weaponEvolution, gamedataWeaponEvolution.Smart) && questSystem.GetFact(n"smart_weapon_tutorial") == 0) {
            questSystem.SetFact(n"smart_weapon_tutorial", 1);
        } else {
            if (Equals(weaponEvolution, gamedataWeaponEvolution.Tech) && RPGManager.IsTechPierceEnabled(this.GetGame(), this, evt.itemID) && questSystem.GetFact(n"tech_weapon_tutorial") == 0) {
                questSystem.SetFact(n"tech_weapon_tutorial", 1);
            } else {
                if (Equals(weaponEvolution, gamedataWeaponEvolution.Power) && RPGManager.IsRicochetChanceEnabled(this.GetGame(), this, evt.itemID) &&
                questSystem.GetFact(n"power_weapon_tutorial") == 0 && evt.itemID != ItemID.CreateQuery(t"Items.Preset_V_Unity_Cutscene") &&
                evt.itemID != ItemID.CreateQuery(t"Items.Preset_V_Unity")) {
                    questSystem.SetFact(n"power_weapon_tutorial", 1);
                };
            };
        };
        if (Equals(itemCategory, gamedataItemCategory.Gadget) && questSystem.GetFact(n"grenade_inventory_tutorial") == 0) {
            questSystem.SetFact(n"grenade_inventory_tutorial", 1);
        } else {
            if (Equals(itemCategory, gamedataItemCategory.Cyberware) && questSystem.GetFact(n"cyberware_inventory_tutorial") == 0) {
                questSystem.SetFact(n"cyberware_inventory_tutorial", 1);
            };
        };
        if ((Equals(itemType, gamedataItemType.Con_Inhaler) || Equals(itemType, gamedataItemType.Con_Injector)) && questSystem.GetFact(n"consumable_inventory_tutorial") == 0) {
            questSystem.SetFact(n"consumable_inventory_tutorial", 1);
        };
        if (RPGManager.IsItemIconic(evt.itemData) && Equals(itemCategory, gamedataItemCategory.Weapon) && questSystem.GetFact(n"iconic_item_tutorial") == 0) {
            questSystem.SetFact(n"iconic_item_tutorial", 1);
        };
    };

    if (questSystem.GetFact(n"initial_gadget_picked") == 0) {
        if (Equals(RPGManager.GetItemCategory(evt.itemID), gamedataItemCategory.Gadget)) {
            questSystem.SetFact(n"initial_gadget_picked", 1);
        };
    };

    RPGManager.ProcessOnLootedPackages(this, evt.itemID);
    if (Equals(itemQuality, gamedataQuality.Legendary) || Equals(itemQuality, gamedataQuality.Iconic)) {
        GameInstance.GetAutoSaveSystem(this.GetGame()).RequestCheckpoint();
    };
}

// This unlocks item upgrade menu in UI by not filtering out nonIconics
@replaceMethod(UpgradingScreenController)
private final func GetUpgradableList() -> array<ref<IScriptable>> {
    let i: Int32;
    let itemArrayHolder: array<ref<IScriptable>>;
    this.m_inventoryManager.MarkToRebuild();
    i = 0;
    while i < ArraySize(this.m_WeaponAreas) {
        // Not needed as it duplicates with usual array
        // let iconicArray = this.m_inventoryManager.GetPlayerIconicWeaponsByType(this.m_WeaponAreas[i]);
        let usualArray = this.m_inventoryManager.GetPlayerItemsByType(this.m_WeaponAreas[i]);

        this.FillInventoryData(usualArray, itemArrayHolder);

        i += 1;
    };
    return itemArrayHolder;
}

// Had to replace as it was messing with logic and UI
@replaceMethod(RPGManager)
public final static func GetItemTierForUpgrades(itemData: wref<gameItemData>) -> gamedataQuality {
    if (IsDefined(itemData)) {
        return RPGManager.GetItemQuality(itemData.GetStatValueByType(gamedataStatType.Quality));
    };

    return gamedataQuality.Invalid;
}

// It might be not needed as it could ultimately be trimmed out
@addMethod(CraftingSystem)
private func DetermineItemQualityAndTierCorretly(itemData: wref<gameItemData>) -> array<Float> {
    let itemQuality: gamedataQuality = RPGManager.GetItemQuality(itemData);
    let itemQualityValue: Float = RPGManager.ItemQualityEnumToValue(itemQuality);
    let itemTierQualityValue: Float = itemQualityValue * 2.0;
    let isPlus: Float = RPGManager.GetItemPlus(itemData);
    let result: array<Float>;
    
    ArrayPush(result, itemQualityValue);
    ArrayPush(result, isPlus);
    if (Cast<Bool>(isPlus)) {
        ArrayPush(result, itemTierQualityValue + 1.0);
    } else {
        ArrayPush(result, itemTierQualityValue);
    }

    return result;
}

// We have to look at this first because without it will always use wrong itemComponents
// Essentially I've replaced original method and use it instead. Maybe just replace that one?
@addMethod(CraftingSystem)
public final const func GetItemUpgradeCostCorrectly(itemData: wref<gameItemData>, itemQualityValues: array<Float>) -> array<IngredientData> {
    let i: Int32;
    let ingredients: array<IngredientData>;
    let tempStat: Float;
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
    let itemQuality: gamedataQuality = RPGManager.GetItemQuality(itemQualityValues[0]);

    // let isPlus: Bool = Cast<Bool>(itemQualityValues[1]);
    // let itemTierQuality: gamedataQuality = RPGManager.GetItemTierForUpgrades(itemQualityValues[2]);
    // LogChannel(n"DEBUG", s"GetItemFinalUpgradeCost itemQuality: \(itemQuality)");
    // LogChannel(n"DEBUG", s"GetItemFinalUpgradeCost isPlus: \(isPlus)");
    // LogChannel(n"DEBUG", s"GetItemFinalUpgradeCost itemTierQuality: \(itemTierQuality)");

    // Here we have to pass actual item quality tier [0...4] that is going to be used to upgrade item
    // It does not matter to us if item is base or isPlus. Upgrading to next tier is still same quality
    ingredients = this.GetItemBaseUpgradeCost(itemData.GetItemType(), itemQuality);

    i = 0;
    while i < ArraySize(ingredients) {
        ingredients[i].quantity = ingredients[i].quantity;
        ingredients[i].baseQuantity = ingredients[i].quantity;
        i += 1;
    };

    tempStat = statsSystem.GetStatValue(Cast<StatsObjectID>(this.m_playerCraftBook.GetOwner().GetEntityID()), gamedataStatType.UpgradingCostReduction);
    if (tempStat > 0.00) {
        i = 0;
        while i < ArraySize(ingredients) {
            ingredients[i].quantity = Cast<Int32>(Cast<Float>(ingredients[i].quantity) * (1.00 - tempStat));
            i += 1;
        };
    };
    return ingredients;
}

// TODO: Fix to upgrade to PlusPlus
// Core thing in the entire mod on top of UI changes done
@replaceMethod(CraftingSystem)
private final func UpgradeItem(owner: wref<GameObject>, itemID: ItemID) -> Void {
    let ingredientQuality: gamedataQuality;
    let recipeXP: Int32;
    let xpID: TweakDBID;
    let randF: Float = RandF();

    let currentGameInstance = this.GetGameInstance();
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(currentGameInstance);
    let TS: ref<TransactionSystem> = GameInstance.GetTransactionSystem(currentGameInstance);
    let itemData: wref<gameItemData> = TS.GetItemData(owner, itemID);
   
    let mod: ref<gameStatModifierData>;
    let plusToUpgradeMod: ref<gameStatModifierData>;
    let upgradeToPlusMod: ref<gameStatModifierData>;
    let upgradeToQualityMod: ref<gameStatModifierData>;
    
    let oldVal: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let newVal: Float; // = oldVal + 1.00;
    let itemQuality: Float;

    // LogChannel(n"DEBUG", s"UpgradeItem WasItemUpgraded(oldVal): \(oldVal)");

    let actualUpgradeNumbers: array<Float> = this.DetermineItemQualityAndTierCorretly(itemData);
    let isPlus: Float = actualUpgradeNumbers[1];
    let isPlusBool: Bool = (isPlus > 0.0) ? true : false;
    // let wasItemUpgraded: Float = oldVal;
    // let itemTierQuality: gamedataQuality = RPGManager.GetItemTierForUpgrades(wasItemUpgraded);
    let itemQualityName: gamedataQuality = RPGManager.GetItemQuality(actualUpgradeNumbers[0]);

    statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.WasItemUpgraded, true);
    if (isPlusBool && !(Equals(itemQualityName, gamedataQuality.Legendary))) {
        // LogChannel(n"DEBUG", s"UpgradeItem isPlus to next tier");

        // If itemTier value is lower than it should be - replace it with actual one
        if (oldVal <= actualUpgradeNumbers[2]) {
            oldVal = actualUpgradeNumbers[2];
        }
        // If we are upgrading from isPlus to next quality gets a bump
        itemQuality = actualUpgradeNumbers[0] + 1.0;
        newVal = oldVal + 1.00;
        plusToUpgradeMod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
        upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQuality);

        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), plusToUpgradeMod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
    } else if (isPlusBool && (Equals(itemQualityName, gamedataQuality.Legendary))) {
        // LogChannel(n"DEBUG", s"UpgradeItem legendary isPlus to isPlusPlus");

        itemQuality = actualUpgradeNumbers[0];
        newVal = oldVal + 1.00;

        // LogChannel(n"DEBUG", s"UpgradeItem itemQuality: \(itemQuality)");
        // LogChannel(n"DEBUG", s"UpgradeItem newVal: \(newVal)");

        mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
        upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 2.0);
        upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQuality);

        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
    } else {
        // LogChannel(n"DEBUG", s"UpgradeItem to isPlus");
        // If itemTier value is the same as itemQuality
        if (oldVal <= actualUpgradeNumbers[0]) {
            oldVal = actualUpgradeNumbers[0];
        }
        // If we are upgrading from base to isPlus nothing changes for itemQuality
        itemQuality = actualUpgradeNumbers[0];
        // But itemQualityTier has to go up as it will be stored in WasItemUpgraded
        newVal = actualUpgradeNumbers[2] + 1.00;

        mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
        upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 1.0);
        upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQuality);

        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
    }

    let tempStat: Float = statsSystem.GetStatValue(Cast<StatsObjectID>(owner.GetEntityID()), gamedataStatType.UpgradingMaterialRetrieveChance);
    let ingredients: array<IngredientData> = this.GetItemUpgradeCostCorrectly(itemData, actualUpgradeNumbers);
    let i: Int32 = 0;
    while i < ArraySize(ingredients) {
        if randF >= tempStat {
            TS.RemoveItemByTDBID(owner, ingredients[i].id.GetID(), ingredients[i].quantity, true);
        };
        ingredientQuality = RPGManager.GetItemQualityFromRecord(TweakDBInterface.GetItemRecord(ingredients[i].id.GetID()));

        switch ingredientQuality {
            case gamedataQuality.Common:
                xpID = t"Constants.CraftingSystem.commonIngredientXP";
                break;
            case gamedataQuality.Uncommon:
                xpID = t"Constants.CraftingSystem.uncommonIngredientXP";
                break;
            case gamedataQuality.Rare:
                xpID = t"Constants.CraftingSystem.rareIngredientXP";
                break;
            case gamedataQuality.Epic:
                xpID = t"Constants.CraftingSystem.epicIngredientXP";
                break;
            case gamedataQuality.Legendary:
                xpID = t"Constants.CraftingSystem.legendaryIngredientXP";
                break;
            default:
        };
        recipeXP += TweakDBInterface.GetInt(xpID, 0) * ingredients[i].quantity;
        i += 1;
    };
       
    this.ProcessCraftSkill(Cast<Float>(recipeXP));
    // LogChannel(n"DEBUG", s"-----------------------------------");
}

// This has to replaced because items without proper tags can not be upgraded and they wont work in preview interface
@replaceMethod(CraftingSystem)
private final func CraftItem(target: wref<GameObject>, itemRecord: ref<Item_Record>, amount: Int32, opt ammoBulletAmount: Int32) -> wref<gameItemData> {
    let craftedItemID: ItemID;
    let i: Int32;
    let ingredient: ItemID;
    let ingredientQuality: gamedataQuality;
    let ingredientRecords: array<wref<RecipeElement_Record>>;
    let isAmmo: Bool;
    let itemData: wref<gameItemData>;
    let j: Int32;
    let recipeXP: Int32;
    let requiredIngredients: array<IngredientData>;
    let savedAmount: Int32;
    let savedAmountLocked: Bool;
    let tempStat: Float;
    let xpID: TweakDBID;
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
    let randF: Float = RandF();

    itemRecord.CraftingData().CraftingRecipe(ingredientRecords);
    requiredIngredients = this.GetItemCraftingCost(itemRecord);
    isAmmo = itemRecord.TagsContains(n"Ammo");

    i = 0;
    while i < ArraySize(requiredIngredients) {
      ingredient = ItemID.CreateQuery(requiredIngredients[i].id.GetID());
      if (RPGManager.IsItemWeapon(ingredient) || RPGManager.IsItemClothing(ingredient) || RPGManager.IsItemMisc(ingredient)) {
        itemData = transactionSystem.GetItemData(target, ingredient);
        if (IsDefined(itemData) && itemData.HasTag(n"Quest")) {
          itemData.RemoveDynamicTag(n"Quest");
        };
        this.ClearNonIconicSlots(itemData);
        break;
      };
      i += 1;
    };

    tempStat = statsSystem.GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.CraftingMaterialRetrieveChance);
    savedAmount = 0;
    i = 0;
    while i < ArraySize(requiredIngredients) {
      ingredient = ItemID.CreateQuery(requiredIngredients[i].id.GetID());
      if (RPGManager.IsItemWeapon(ingredient) || RPGManager.IsItemClothing(ingredient) || RPGManager.IsItemProgram(ingredient) || RPGManager.IsItemGadget(ingredient)) {
        randF = 100.00;
      } else {
        if (tempStat > 0.00 && !savedAmountLocked) {
          j = 0;
          while j < amount {
            if RandF() < tempStat {
              savedAmount += 1;
            };
            j += 1;
          };
          savedAmountLocked = true;
        };
      };

      transactionSystem.RemoveItemByTDBID(target, ItemID.GetTDBID(ingredient), requiredIngredients[i].quantity * (amount - savedAmount), true);
      if (randF >= tempStat && (RPGManager.IsItemWeapon(ingredient) || RPGManager.IsItemClothing(ingredient) || RPGManager.IsItemProgram(ingredient))) {
        transactionSystem.RemoveItemByTDBID(target, ItemID.GetTDBID(ingredient), requiredIngredients[i].quantity * amount, true);
      };

      ingredientQuality = RPGManager.GetItemQualityFromRecord(TweakDBInterface.GetItemRecord(requiredIngredients[i].id.GetID()));
      switch (ingredientQuality) {
        case gamedataQuality.Common:
          xpID = t"Constants.CraftingSystem.commonIngredientXP";
          break;
        case gamedataQuality.Uncommon:
          xpID = t"Constants.CraftingSystem.uncommonIngredientXP";
          break;
        case gamedataQuality.Rare:
          xpID = t"Constants.CraftingSystem.rareIngredientXP";
          break;
        case gamedataQuality.Epic:
          xpID = t"Constants.CraftingSystem.epicIngredientXP";
          break;
        case gamedataQuality.Legendary:
          xpID = t"Constants.CraftingSystem.legendaryIngredientXP";
          break;
        default:
      };
      recipeXP += TweakDBInterface.GetInt(xpID, 0) * requiredIngredients[i].baseQuantity * amount;
      i += 1;
    };

    craftedItemID = ItemID.FromTDBID(itemRecord.GetID());
    transactionSystem.GiveItem(target, craftedItemID, isAmmo ? amount * ammoBulletAmount : amount);
    
    if (Equals(itemRecord.ItemType().Type(), gamedataItemType.Gad_Grenade) || Equals(itemRecord.ItemType().Type(), gamedataItemType.Con_Inhaler) || Equals(itemRecord.ItemType().Type(), gamedataItemType.Con_Injector)) {
      this.ProcessProgramCrafting(itemRecord.GetID());
    };

    itemData = transactionSystem.GetItemData(target, craftedItemID);
    let isItemWeapon = RPGManager.GetItemCategory(itemData.GetID());

    if (Equals(isItemWeapon, gamedataItemCategory.Weapon)) {
        let itemQuality = RPGManager.GetItemQuality(itemData);
        let itemQualityValue = RPGManager.ItemQualityEnumToValue(itemQuality);
        // LogChannel(n"DEBUG", s"CraftItem itemQuality: \(itemQuality)");

        let plusToUpgradeMod: ref<gameStatModifierData>;
        let upgradeToQualityMod: ref<gameStatModifierData>;

        // TODO: Add additional check if player is lvl 50 and wants to craft ++ straight away

        plusToUpgradeMod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, itemQualityValue);
        upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);

        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), plusToUpgradeMod);
        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
        statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
    }
    
    this.SetItemLevel(itemData);
    this.MarkItemAsCrafted(itemData);
    this.SendItemCraftedDataTrackingRequest(craftedItemID);
    this.ProcessCraftSkill(Cast<Float>(recipeXP));
    
    return itemData;
}

// @replaceMethod(UpgradingScreenController)
// private final func UpgradeItem(const selectedItemData: script_ref<InventoryItemData>) -> Void {
//     LogChannel(n"DEBUG", s"UpgradingScreenController UpgradeItem");

//     let itemQuality: gamedataQuality = RPGManager.GetItemTierForUpgrades(InventoryItemData.GetGameItemData(this.m_selectedItemData));
//     let isEmpty: Bool = this.IsEmptyData();
//     let isLastUpgrade: Bool = this.IsLastUpgrade(itemQuality);
//     let upgradeItemRequest: ref<UpgradeItemRequest> = new UpgradeItemRequest();

//     LogChannel(n"DEBUG", s"UpgradingScreenController itemQuality: \(itemQuality)");
//     LogChannel(n"DEBUG", s"UpgradingScreenController isLastUpgrade: \(isLastUpgrade)");
    
//     upgradeItemRequest.owner = this.m_craftingGameController.GetPlayer();
//     upgradeItemRequest.itemID = Deref(selectedItemData).ID;
    
//     this.m_craftingSystem.QueueRequest(upgradeItemRequest);

//     if (isLastUpgrade && !isEmpty) {
//         this.DispatchSelectDelayed(0u);
//     };
// }

// Use this for debug data
// @replaceMethod(UpgradingScreenController)
// private final func UpdateTooltipData() -> Void {
//     let delayedCall: ref<DelayedTooltipCall> = this.CreateDelayedCall();
//     let itemData: ref<gameItemData> = InventoryItemData.GetGameItemData(this.m_selectedItemData);

//     let itemQualityName: gamedataQuality = RPGManager.GetItemQuality(itemData);
//     // let itemQualityValue: Float = RPGManager.ItemQualityEnumToValue(itemQualityName);
//     // let itemTierQualityValue: Float = itemQualityValue * 2.0;
//     // let isPlus: Float = RPGManager.GetItemPlus(itemData);
//     // let wasItemUpgraded = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);

//     // LogChannel(n"DEBUG", s"UpdateTooltipData itemQualityName: \(itemQualityName)");
//     // LogChannel(n"DEBUG", s"UpdateTooltipData wasItemUpgraded: \(wasItemUpgraded)");
//     // LogChannel(n"DEBUG", s"UpdateTooltipData itemTierQualityValue: \(itemTierQualityValue)");
//     // LogChannel(n"DEBUG", s"UpdateTooltipData isPlus: \(isPlus)");
//     // LogChannel(n"DEBUG", s"-----------------------------------");

//     let isQualityShown: Bool = this.IsQualityShown(itemQualityName);
//     let check: Bool = this.m_isCraftable || isQualityShown;
//     // LogChannel(n"DEBUG", s"UpdateTooltipData check: \(check)");
//     // LogChannel(n"DEBUG", s"UpdateTooltipData ------------------------------------------------");
//     if (check) {
//       this.UpdateTooltipLeft();
//       this.m_DelaySystem.DelayCallback(delayedCall, this.DELAYED_TOOLTIP_RIGHT, false);
//       return;
//     };
//     this.HideTooltips();
// }

// This has to be replaced because otherwise we would have to replace another method and it is
// just easier to fix this by invoking new methods
@replaceMethod(UpgradingScreenController)
public final func UpdateTooltipRightAndShow() -> Void {
    this.UpgradeItemForPreview();
    this.m_tooltipDataRight = this.m_inventoryManager.GetMinimalTooltipDataForInventoryItem(this.m_selectedItemData, false, null, false);
    this.m_tooltipDataRight.isEquipped = false;
    this.m_tooltipDataRight.price = Cast<Float>(RPGManager.CalculateSellPriceItemData(this.m_Game, this.m_Player, InventoryItemData.GetGameItemData(this.m_selectedItemData)));
    this.m_tooltipDataRight.displayContext = InventoryTooltipDisplayContext.Upgrading;
    this.FillBarsComparisonData(this.m_tooltipDataLeft, this.m_tooltipDataRight);
    this.m_itemTooltipControllerRight.SetData(this.m_tooltipDataRight);
    this.DegradeItemForPreview();
    this.ShowTooltips();
}

// Upgrades item to next level
// TODO: Refactor
@addMethod(UpgradingScreenController)
private func UpgradeItemForPreview() -> Void {
    let itemData: ref<gameItemData> = InventoryItemData.GetGameItemData(this.m_selectedItemData);
    let itemQualityName: gamedataQuality = RPGManager.GetItemQuality(itemData);
    let itemQualityValue: Float = RPGManager.ItemQualityEnumToValue(itemQualityName);
    let itemTierQualityValue: Float = itemQualityValue * 2.0;
    let isPlus: Float = RPGManager.GetItemPlus(itemData);
    let isPlusBool: Bool = (isPlus > 0.0) ? true : false;
    let wasItemUpgraded: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let statsSystem = this.m_StatsSystem;

    // LogChannel(n"DEBUG", s"UpgradeItemForPreview itemQualityName: \(itemQualityName)");
    // LogChannel(n"DEBUG", s"UpgradeItemForPreview wasItemUpgraded: \(wasItemUpgraded)");
    // LogChannel(n"DEBUG", s"UpgradeItemForPreview itemTierQualityValue: \(itemTierQualityValue)");
    // LogChannel(n"DEBUG", s"UpgradeItemForPreview isPlus: \(isPlus)");

    let isItemMaxTier: Bool = RPGManager.IsItemMaxTier(itemData);
    if (!isItemMaxTier) {
        if (wasItemUpgraded > itemTierQualityValue) {
            wasItemUpgraded = itemTierQualityValue;
        }

        let newVal: Float = wasItemUpgraded + 1.00;
        // LogChannel(n"DEBUG", s"UpgradeItemForPreview newVal: \(newVal)");
        let mod: ref<gameStatModifierData>;
        let plusToUpgradeMod: ref<gameStatModifierData>;
        let upgradeToPlusMod: ref<gameStatModifierData>;
        let upgradeToQualityMod: ref<gameStatModifierData>;

        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.WasItemUpgraded, true);
        if (isPlusBool && (Equals(itemQualityName, gamedataQuality.Legendary))) {
            // LogChannel(n"DEBUG", s"UpgradeItemForPreview we upgrade item to Plus Plus");

            mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 2.0);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);

            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        } else if (!isPlusBool) {
            // LogChannel(n"DEBUG", s"UpgradeItemForPreview we upgrade item to Plus");

            mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 1.0);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);

            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        } else {
            // LogChannel(n"DEBUG", s"UpgradeItemForPreview we upgrade item to next tier");

            plusToUpgradeMod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue + 1.0);

            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), plusToUpgradeMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        }
    }
    // LogChannel(n"DEBUG", s"-----------------------------------");
}

// Degrades item to level it was before upgrade
// TODO: Refactor
@addMethod(UpgradingScreenController)
private func DegradeItemForPreview() -> Void {
    let itemData: ref<gameItemData> = InventoryItemData.GetGameItemData(this.m_selectedItemData);
    let itemQualityName: gamedataQuality = RPGManager.GetItemQuality(itemData);
    let itemQualityValue: Float = RPGManager.ItemQualityEnumToValue(itemQualityName);
    let itemTierQualityValue: Float = itemQualityValue * 2.0;
    let isPlus: Float = RPGManager.GetItemPlus(itemData);
    let isPlusBool: Bool = (isPlus > 0.0) ? true : false;
    let wasItemUpgraded: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let statsSystem = this.m_StatsSystem;

    // LogChannel(n"DEBUG", s"DegradeItemForPreview itemQuality: \(itemQualityName)");
    // LogChannel(n"DEBUG", s"DegradeItemForPreview itemTierQualityValue: \(itemTierQualityValue)");
    // LogChannel(n"DEBUG", s"DegradeItemForPreview wasItemUpgraded: \(wasItemUpgraded)");
    // LogChannel(n"DEBUG", s"DegradeItemForPreview isPlus: \(isPlus)");

    let isItemMaxTier: Bool = RPGManager.IsItemMaxTier(itemData);
    if (!isItemMaxTier) {
        if (wasItemUpgraded < itemTierQualityValue) {
            wasItemUpgraded = itemTierQualityValue;
        }

        let newVal: Float = wasItemUpgraded - 1.00;
        // LogChannel(n"DEBUG", s"DegradeItemForPreview newVal: \(newVal)");

        let mod: ref<gameStatModifierData>;
        let plusToUpgradeMod: ref<gameStatModifierData>;
        let upgradeToPlusMod: ref<gameStatModifierData>;
        let upgradeToQualityMod: ref<gameStatModifierData>;

        statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.WasItemUpgraded, true);
        if (isPlusBool && (Equals(itemQualityName, gamedataQuality.Legendary))) {
            // LogChannel(n"DEBUG", s"DegradeItemForPreview we degrade item from Plus Plus");

            mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 1.0);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);

            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        } else if (isPlusBool) {
            // LogChannel(n"DEBUG", s"DegradeItemForPreview we degrade item from Plus");

            plusToUpgradeMod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue);

            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), plusToUpgradeMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        } else {
            // LogChannel(n"DEBUG", s"DegradeItemForPreview we degrade item in quality");

            mod = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, newVal);
            upgradeToPlusMod = RPGManager.CreateStatModifier(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, 1.0);
            upgradeToQualityMod = RPGManager.CreateStatModifier(gamedataStatType.Quality, gameStatModifierType.Additive, itemQualityValue - 1.0);

            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), mod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToPlusMod);
            statsSystem.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
            statsSystem.AddSavedModifier(itemData.GetStatsObjectID(), upgradeToQualityMod);
        }
    }
    // LogChannel(n"DEBUG", s"-----------------------------------");
}