local PetCompareEventFrame = CreateFrame("frame", "PetCompare Frame");
local myPrefix = "PetComparison121";
local PetCompareAddOn_Comms = {};
local petCompareScore = 0; local myDuplicates = {};
local firstPartyShared = nil; local firstPartyMyOffers = nil; local firstPartyTheirOffers = nil;
local secondPartyShared = nil; local secondPartyMyOffers = nil; local secondPartyTheirOffers = nil;
local thirdPartyShared = nil; local thirdPartyMyOffers = nil; local thirdPartyTheirOffers = nil;
local fourthPartyShared = nil; local fourthPartyMyOffers = nil; local fourthPartyTheirOffers = nil;
local sourcesPreviousValue = {};
local typesPreviousValue = {};

local currentTab = nil -- Variable to keep track of the current party index
local SelectGroupFunction = nil -- Variable to store the function reference for selecting a group

-- load variables
local Serializer = LibStub("LibSerialize");
local Deflater = LibStub("LibDeflate");
local AceGUI = LibStub("AceGUI-3.0");
local AceComm = LibStub:GetLibrary("AceComm-3.0");

local DEBUG_MODE = true;

local function debugPrint(msg)
    if DEBUG_MODE then
        print(msg)
    end
end

local function tprint (tbl, indent)
    if not indent then indent = 0 end
    local toprnt = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprnt = toprnt .. string.rep(" ", indent)
      if (type(k) == "number") then
        toprnt = toprnt .. "[" .. k .. "] = "
      elseif (type(k) == "string") then
        toprnt = toprnt  .. k ..  "= "
      end
      if (type(v) == "number") then
        toprnt = toprnt .. v .. ",\r\n"
      elseif (type(v) == "string") then
        toprnt = toprnt .. "\"" .. v .. "\",\r\n"
      elseif (type(v) == "table") then
        toprnt = toprnt .. tprint(v, indent + 2) .. ",\r\n"
      else
        toprnt = toprnt .. "\"" .. tostring(v) .. "\",\r\n"
      end
    end
    toprnt = toprnt .. string.rep(" ", indent-2) .. "}"
    return toprnt
end

local function GetRealUnitName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if name == UNKNOWNOBJECT then return name end

    if realm == nil then
        realm = GetNormalizedRealmName() or GetRealmName():gsub('[%s-]+', '')
    end

    return name .. '-' .. realm
end

function PetCompareAddOn_Comms:Init()
    AceComm:Embed(self);
    self:RegisterComm(self.Prefix, "OnCommReceived");
end

function PetCompareAddOn_Comms:SendAMessage(myPets, channel, target)
	local serialized = Serializer:Serialize(myPets); 
	local compressed = Deflater:CompressDeflate(serialized);
	local encoded = Deflater:EncodeForWoWAddonChannel(compressed)
	-- debugPrint("sending a message via " .. channel)
    if(channel == "PARTY") then
        self:SendCommMessage(myPrefix, encoded, channel);
    elseif(channel == "WHISPER") then
        self:SendCommMessage(myPrefix, encoded, channel, target);
    end
end

function PetCompareAddOn_Comms:OnCommReceived(passedPrefix, msg, distribution, sender)
	if (passedPrefix == myPrefix) then
        if(distribution == "PARTY") then -- it is a distribution of the initiators pets
            local myName = UnitName("player");
            if(sender == myName) then
                return;
            else
                -- debugPrint("I am not the sender. They are: " .. sender .. " I am: " .. myName)
                -- debugPrint("I am answering a comparison request")

                --set search filters so addon doesnt break
                C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED,true);
                C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED,true);
                --save and set sources so they are the same when the user re-opens the journal
                local numSources = C_PetJournal.GetNumPetSources();
                local filterText = C_PetJournal.GetSearchFilter();
                sourcesPreviousValue = {};
                for sourceCounter = 1, numSources, 1 do
                    sourcesPreviousValue[sourceCounter] = C_PetJournal.IsPetSourceChecked(sourceCounter);
                end
                C_PetJournal.SetAllPetSourcesChecked(true);
                C_PetJournal.SetSearchFilter("");

                --save and set pet types
                local numTypes = C_PetJournal.GetNumPetTypes();
                typesPreviousValue = {};
                for typesCounter = 1, numTypes, 1 do
                    typesPreviousValue[typesCounter] = C_PetJournal.IsPetTypeChecked(typesCounter);
                end
                C_PetJournal.SetAllPetTypesChecked(true);

                petCompareScore = 0;
                local  _, numOwned = C_PetJournal.GetNumPets();
                local decoded = Deflater:DecodeForWoWAddonChannel(msg)
                if not decoded then return end
                local decompressed = Deflater:DecompressDeflate(decoded)
                if not decompressed then return end
                local success, theirPets = Serializer:Deserialize(decompressed)
                if not success then return end
                local commonPets = {};
                commonPets["type"] = "common";
                local myOffers = {}
                myOffers["type"] = "partyMembersOffers";
                local theirOffers = {};
                theirOffers["type"] = "startersOffers";
                local myPets = {};
                local myPetOccurences = {};
                local myRarities = {};
                local myLevels = {};
                local pointsAddedForPet = {};

                for secondPlayerCounter = 1, numOwned, 1 do  --go through all my pets
                    local petID, speciesID, _, _, level, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByIndex(secondPlayerCounter);
                    if(petID) then
                        if(myPets[speciesID] == true) then --if I already have come across this pet
                            myPetOccurences[speciesID] = myPetOccurences[speciesID] + 1;
                        else --i have not come across this pet yet
                            myPetOccurences[speciesID] = 1;
                        end

                        if(theirPets[speciesID] == true) then --if they have this pet
                            commonPets[speciesID] = true;--then we both have this pet
                        elseif(theirPets[speciesID] ~= true) then --if they dont have this pet
                            if(myPetOccurences[speciesID] > 1) then --if I have more than 1 of this pet
                                myOffers[speciesID] = true; --then I can offer it
                            end
                        end

                        local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID);
                        if(myPets[speciesID] ~= true) then --if this is the first of a pet
                            myPets[speciesID] = true;
                            myRarities[speciesID] = rarity;
                            myLevels[speciesID] = level;
                            pointsAddedForPet[speciesID] = 0.12 * level;
                            if(rarity == 2) then --if rarity is common
                                pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
                            elseif(rarity == 3) then --if rarity is uncommon
                                pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
                            elseif(rarity == 4) then --if rarity is rare
                                pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
                            elseif(rarity == 5) then --if rarity is epic
                                pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
                            elseif(rarity == 6) then --if rarity is legendary
                                pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
                            end
                            petCompareScore = petCompareScore + 2 + pointsAddedForPet[speciesID];

                        else --if this is a duplicate
                            if(myRarities[speciesID] < rarity) then --if the saved pet was less rare, I need to recalculate
                                petCompareScore = petCompareScore - pointsAddedForPet[speciesID];
                                pointsAddedForPet[speciesID] = 0.12 * level;
                                if(rarity == 2) then --if rarity is common
                                    pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
                                elseif(rarity == 3) then --if rarity is uncommon
                                    pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
                                elseif(rarity == 4) then --if rarity is rare
                                    pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
                                elseif(rarity == 5) then --if rarity is epic
                                    pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
                                elseif(rarity == 6) then --if rarity is legendary
                                    pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
                                end
                                petCompareScore = petCompareScore + pointsAddedForPet[speciesID];
                            elseif(myRarities[speciesID] > rarity) then --if the saved pet was more rare
                                --do nothing
                            else --if the saved pet is as rare as this one
                                if(myLevels[speciesID] > level)then --if the saved pet had a higher level
                                    --do nothing
                                elseif(myLevels[speciesID] == level) then --if the saved pet has the same level
                                    --do nothing
                                else -- if the saved pet has a lower level, I need to recalculate
                                    petCompareScore = petCompareScore - pointsAddedForPet[speciesID];
                                    pointsAddedForPet[speciesID] = 0.12 * level;
                                    if(rarity == 2) then --if rarity is common
                                        pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
                                    elseif(rarity == 3) then --if rarity is uncommon
                                        pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
                                    elseif(rarity == 4) then --if rarity is rare
                                        pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
                                    elseif(rarity == 5) then --if rarity is epic
                                        pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
                                    elseif(rarity == 6) then --if rarity is legendary
                                        pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
                                    end
                                    petCompareScore = petCompareScore + pointsAddedForPet[speciesID];
                                end
                            end
                        end
                    end --if speciesName
                end --for loop for my own pets
                --need to find out how many of their pets I dont have. do for each in theirPets, exclude the type, and score indices
                for k,_ in pairs(theirPets) do
                    if(commonPets[k] ~= true) then --go through all of theirPets, and any pet which is not shared, must be a possible offer.
                        theirOffers[k] = true;
                    end
                end
                commonPets["score"] = Round(petCompareScore);
                PetCompareAddOn_Comms:SendAMessage(commonPets, "WHISPER", sender);
                PetCompareAddOn_Comms:SendAMessage(myOffers, "WHISPER", sender);
                PetCompareAddOn_Comms:SendAMessage(theirOffers, "WHISPER", sender);

                numSources = C_PetJournal.GetNumPetSources();
                for sourceCounter = 1, numSources, 1 do
                    C_PetJournal.SetPetSourceChecked(sourceCounter, sourcesPreviousValue[sourceCounter])
                end
                numTypes = C_PetJournal.GetNumPetTypes();
                for typesCounter = 1, numTypes, 1 do
                    C_PetJournal.SetPetTypeFilter(typesCounter, typesPreviousValue[typesCounter])
                end
                C_PetJournal.SetSearchFilter(filterText);

            end
        elseif (distribution == "WHISPER") then
            debugPrint("I got a response to my comparison  from " .. sender)
            local decoded = Deflater:DecodeForWoWAddonChannel(msg)
            if not decoded then return end
            local decompressed = Deflater:DecompressDeflate(decoded)
            if not decompressed then return end
            local success, responseTable = Serializer:Deserialize(decompressed)
            if not success then return end
            
            local totalMembers = GetNumGroupMembers();
            for counter = 1, totalMembers-1, 1 do
                local index = "party" .. counter;
                local theirName = GetRealUnitName(index);
                local normalizedSender = sender
                if not normalizedSender:find("-") then
                    local myRealm = GetNormalizedRealmName() -- Get your server's name
                    normalizedSender = normalizedSender .. "-" .. myRealm
                end

                if(theirName == normalizedSender) then --if the sender matches this party members name, 
                    -- debugPrint("I found a match for " .. theirName .. " at index " .. index)
                    if(counter == 1) then
                        if(responseTable["type"] == "common") then
                            debugPrint("I received their shared pets")
                            firstPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            debugPrint("it is my offers")
                            firstPartyMyOffers = {};
                            for k,_ in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    firstPartyMyOffers[k] = true;
                                end
                            end
                            debugPrint("done computing my offers")
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            debugPrint("it is their offers")
                            firstPartyTheirOffers = responseTable;
                        end

                    elseif(counter == 2) then
                        if(responseTable["type"] == "common") then
                            debugPrint("I received their shared pets")
                            secondPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            debugPrint("it is my offers")
                            secondPartyMyOffers = {};
                            for k,_ in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    secondPartyMyOffers[k] = true;
                                end
                            end
                            debugPrint("done computing my offers")
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            debugPrint("it is their offers")
                            secondPartyTheirOffers = responseTable;
                        end

                    elseif(counter == 3) then
                        if(responseTable["type"] == "common") then
                            debugPrint("I received their shared pets")
                            thirdPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            debugPrint("it is my offers")
                            thirdPartyMyOffers = {};
                            for k,_ in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    thirdPartyMyOffers[k] = true;
                                end
                            end
                            debugPrint("done computing my offers")
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            debugPrint("it is their offers")
                            thirdPartyTheirOffers = responseTable;
                        end

                    else
                        if(responseTable["type"] == "common") then
                            debugPrint("I received their shared pets")
                            fourthPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            debugPrint("it is my offers")
                            fourthPartyMyOffers = {};
                            for k,_ in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    fourthPartyMyOffers[k] = true;
                                end
                            end
                            debugPrint("done computing my offers")
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            debugPrint("it is their offers")
                            fourthPartyTheirOffers = responseTable;
                        end
                    end

                    --if the message received is from the current party member, rcall SelectGroup
                    if tonumber(currentTab:match("%d+")) == counter then
                        -- debugPrint("I received a message from the party member whos tab is selected, so I will call SelectGroup")
                        SelectGroupFunction(nil, nil, currentTab)
                    else
                        -- debugPrint("I received a message from the party member whos tab is not selected, so I will not call SelectGroup")
                        -- debugPrint("currentTab is: " .. currentTab .. " and the party member is: " .. counter)
                    end
                    break;
                end
            end
        end
	end--if
end

function PetCompareEventFrame:CreatePetCompareWindow()
    -- Create the main frame container
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("PetCompare")
	frame:SetStatusText("PetCompare created by Van on Stormrage.")
	frame:SetCallback("OnClose", function(widget)
		firstPartyShared = nil; firstPartyMyOffers = nil; firstPartyTheirOffers = nil;
		secondPartyShared = nil; secondPartyMyOffers = nil; secondPartyTheirOffers = nil;
		thirdPartyShared = nil; thirdPartyMyOffers = nil; thirdPartyTheirOffers = nil;
		fourthPartyShared = nil; fourthPartyMyOffers = nil; fourthPartyTheirOffers = nil;
		AceGUI:Release(widget)
	end)
	-- Fill Layout - the TabGroup widget will fill the whole frame
	frame:SetLayout("Fill")

	-- Create the TabGroup
	local tab =  AceGUI:Create("TabGroup");
	petCompareScore = Round(petCompareScore);
	tab:SetTitle("My pet score: " ..petCompareScore);
	tab:SetLayout("Flow");

    local function CreatePartyTab(tabGroup, partyIndex, partyName)
        --Helper function to create the compare UI
        local function CreateCompareUI(container, name)
            local function DrawSharedTab(container, name, shared)
                local sharedScrollcontainer = AceGUI:Create("SimpleGroup");
                sharedScrollcontainer:SetFullWidth(true);
                sharedScrollcontainer:SetFullHeight(true);
                sharedScrollcontainer:SetLayout("Fill");

                container:AddChild(sharedScrollcontainer);

                local sharedScroll = AceGUI:Create("ScrollFrame");
                sharedScroll:SetLayout("Flow");
                sharedScrollcontainer:AddChild(sharedScroll);

                local count = 0;
                for k,_ in pairs(shared) do
                    if(k == "score") then
                        --do nothing
                    elseif(k == "type") then
                        --do nothing
                    else
                        count = count +1;
                    end
                end
                if(count > 0) then
                    for k,_ in pairs(shared) do
                        if(k == "score") then
                            --do nothing
                        elseif(k == "type") then
                            --do nothing
                        else
                            local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(k)
                            local icon = AceGUI:Create("Icon");
                            icon:SetImage(speciesIcon);
                            icon:SetLabel(speciesName);
                            icon:SetImageSize(50,50);
                            icon.speciesName = speciesName;

                            icon:SetCallback("OnClick",function()
                                SetCollectionsJournalShown(true, 2);
                                C_Timer.After(0.1, function()
                                    C_PetJournal.SetSearchFilter(icon.speciesName);
                                end)
                            end)
                            sharedScroll:AddChild(icon);
                        end
                    end
                else
                    local PetCompareLabel = AceGUI:Create("Label");
                    PetCompareLabel:SetText("You and " .. name .. " have no pets in common.")
                    PetCompareLabel:SetFullWidth(true)
                    sharedScroll:AddChild(PetCompareLabel);
                end
            end

            local function DrawMyOffersTab(container, name, myOffers)
                local myOffersScrollContainer = AceGUI:Create("SimpleGroup");
                myOffersScrollContainer:SetFullWidth(true);
                myOffersScrollContainer:SetFullHeight(true);
                myOffersScrollContainer:SetLayout("Fill");

                container:AddChild(myOffersScrollContainer);

                local myOffersScroll = AceGUI:Create("ScrollFrame");
                myOffersScroll:SetLayout("Flow");
                myOffersScrollContainer:AddChild(myOffersScroll);

                local count = 0;
                for k,_ in pairs(myOffers) do
                    if(k == "score") then
                        --do nothing
                    elseif(k == "type") then
                        --do nothing
                    else
                        count = count +1;
                    end
                end
                if(count > 0) then
                    for k,_ in pairs(myOffers) do
                        if(k == "score") then
                            --do nothing
                        elseif(k == "type") then
                            --do nothing
                        else
                            local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(k);
                            local icon = AceGUI:Create("Icon");
                            icon:SetImage(speciesIcon);
                            icon:SetLabel(speciesName);
                            icon:SetImageSize(50,50);
                            icon.speciesName = speciesName;

                            icon:SetCallback("OnClick",function()
                                SetCollectionsJournalShown(true, 2);
                                C_Timer.After(0.1, function()
                                    C_PetJournal.SetSearchFilter(icon.speciesName);
                                end)
                            end)
                            myOffersScroll:AddChild(icon);
                        end	
                    end


                else
                    local PetCompareLabel = AceGUI:Create("Label");
                    PetCompareLabel:SetText("You cannot offer " .. name .. " any pets");
                    PetCompareLabel:SetFullWidth(true)
                    myOffersScroll:AddChild(PetCompareLabel);
                end
            end

            local function DrawTheirOffersTab(container, name, theirOffers)
                local theirOffersScrollContainer = AceGUI:Create("SimpleGroup");
                theirOffersScrollContainer:SetFullWidth(true);
                theirOffersScrollContainer:SetFullHeight(true);
                theirOffersScrollContainer:SetLayout("Fill");

                container:AddChild(theirOffersScrollContainer);

                local theirOffersScroll = AceGUI:Create("ScrollFrame");
                theirOffersScroll:SetLayout("Flow");
                theirOffersScrollContainer:AddChild(theirOffersScroll);

                local count = 0;
                for k,_ in pairs(theirOffers) do
                    if(k == "score") then
                        --do nothing
                    elseif(k == "type") then
                        --do nothing
                    else
                        count = count +1;
                    end
                end
                if(count > 0) then
                    for k,_ in pairs(theirOffers) do
                        if(k == "score") then
                            --do nothing
                        elseif(k == "type") then
                            --do nothing
                        else
                            local speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(k)
                            local icon = AceGUI:Create("Icon");
                            icon:SetImage(speciesIcon);
                            icon:SetLabel(speciesName);
                            icon:SetImageSize(50,50);
                            icon.speciesName = speciesName;

                            icon:SetCallback("OnClick",function()
                                SetCollectionsJournalShown(true, 2);
                                C_Timer.After(0.1, function()
                                    C_PetJournal.SetSearchFilter(icon.speciesName);
                                end)
                            end)
                            theirOffersScroll:AddChild(icon);
                        end
                    end
                else
                    local PetCompareLabel = AceGUI:Create("Label");
                    PetCompareLabel:SetText(name .. " has no pets to offer you.")
                    PetCompareLabel:SetFullWidth(true)
                    theirOffersScroll:AddChild(PetCompareLabel);
                end
            end

            -- Callback function for OnGroupSelected in compare ui
            local function SelectPetGroup(container, _, group)
                local function DisplayLoading(container, name)
                    local PetCompareLabel = AceGUI:Create("Label");
                    PetCompareLabel:SetText(name .. "'s pets are loading...");
                    PetCompareLabel:SetFullWidth(true)
                    container:AddChild(PetCompareLabel);
                end

                container:ReleaseChildren();
                local shared, myOffers, theirOffers = nil, nil, nil;
                if(partyIndex == 1) then
                    shared = firstPartyShared;
                    myOffers = firstPartyMyOffers;
                    theirOffers = firstPartyTheirOffers;
                elseif(partyIndex == 2) then
                    shared = secondPartyShared;
                    myOffers = secondPartyMyOffers;
                    theirOffers = secondPartyTheirOffers;
                elseif(partyIndex == 3) then
                    shared = thirdPartyShared;
                    myOffers = thirdPartyMyOffers;
                    theirOffers = thirdPartyTheirOffers;
                elseif(partyIndex == 4) then
                    shared = fourthPartyShared;
                    myOffers = fourthPartyMyOffers;
                    theirOffers = fourthPartyTheirOffers;
                end
                if group == "sharedPets" then
                    if(shared == nil) then
                        DisplayLoading(container, name);
                    else
                        DrawSharedTab(container, partyName, shared);
                    end
                elseif group == "myOffers" then
                    if(myOffers == nil) then
                        DisplayLoading(container, name);
                    else
                        DrawMyOffersTab(container, partyName, myOffers);
                    end
                elseif group == "theirOffers" then
                    if(theirOffers == nil) then
                        DisplayLoading(container, name);
                    else
                        DrawTheirOffersTab(container, partyName, theirOffers);
                    end
                end
            end

            local theirScore = nil;
            if(partyIndex == 1) then
                theirScore = firstPartyShared["score"];
            elseif(partyIndex == 2) then
                theirScore = secondPartyShared["score"];
            elseif(partyIndex == 3) then
                theirScore = thirdPartyShared["score"];
            elseif(partyIndex == 4) then
                theirScore = fourthPartyShared["score"];
            end

            local PetCompareScoreLabel = AceGUI:Create("Label");
			PetCompareScoreLabel:SetText(name .."'s pet score: " .. theirScore ); -- this only works with the first party member 
			if(petCompareScore > theirScore) then -- if my score is higher
				PetCompareScoreLabel:SetColor(0,255,0); --make it green
			elseif(petCompareScore == theirScore) then --if we have the same score
				PetCompareScoreLabel:SetColor(0,255,42); -- make it yellow
			else --if their score is higher
				PetCompareScoreLabel:SetColor(255,0,0); --make it red
			end

			local button = AceGUI:Create("Button");
			button:SetText("Tell " .. name .. " that you compared pets");
			button:SetCallback("OnClick",
			function() 
				SendChatMessage("Hey " .. name .. " I compared pets with you!", "party");
			end)
			button:SetWidth(325);

			local scoreAndButtonContainer = AceGUI:Create("SimpleGroup");
			scoreAndButtonContainer:SetLayout("Flow");
			scoreAndButtonContainer:SetFullWidth(true);
			scoreAndButtonContainer:AddChild(PetCompareScoreLabel);
			scoreAndButtonContainer:AddChild(button);
			container:AddChild(scoreAndButtonContainer);

			-- Create the TabGroup for shared/my offers/their offers
			local compareTab =  AceGUI:Create("TabGroup");
			compareTab:SetLayout("Flow");
			compareTab:SetFullWidth(true);
			compareTab:SetFullHeight(true);
			--setup tabs
			compareTab:SetTabs( { {text="Shared Pets", value="sharedPets"}, {text="My Offers", value="myOffers"}, {text="Their Offers", value="theirOffers"} } )
			-- Register callback
			compareTab:SetCallback("OnGroupSelected", SelectPetGroup)
			-- Set initial Tab (this will fire the OnGroupSelected callback)
			compareTab:SelectTab("sharedPets")

			-- add to the frame container
			container:AddChild(compareTab);
        end

        -- Helper function to create the label and button
        local function CreateNilStateUI(TabContainer, partyName)
            -- Create a label for this tab
            local CompareLabel = AceGUI:Create("Label")
            CompareLabel:SetText(partyName .. " does not have the addon so you could not compare.")
            CompareLabel:SetFullWidth(true)
            TabContainer:AddChild(CompareLabel)

            -- Create a button for this tab
            local AnnounceButton = AceGUI:Create("Button")
            AnnounceButton:SetText("Tell " .. partyName .. " that you tried to compare pets")
            AnnounceButton:SetCallback("OnClick", function()
                SendChatMessage("Hey " .. partyName .. " I tried to compare pets with you!", "party")
            end)
            AnnounceButton:SetWidth(325)
            TabContainer:AddChild(AnnounceButton)
        end

        -- Create a container for this tab
        local TabContainer = AceGUI:Create("SimpleGroup")
        TabContainer:SetFullWidth(true)
        TabContainer:SetFullHeight(true)
        TabContainer:SetLayout("Flow")

        if(partyIndex == 1) then
            -- check if firstPartyShared, firstPartyMyOffers, firstPartyTheirOffers is nil
            if(firstPartyShared == nil) then
                CreateNilStateUI(TabContainer, partyName)
            else
                CreateCompareUI(TabContainer, partyName)
            end
        elseif(partyIndex == 2) then
            -- check secondPartyShared, secondPartyMyOffers, secondPartyTheirOffers
            if(secondPartyShared == nil) then
                CreateNilStateUI(TabContainer, partyName)
            else
                CreateCompareUI(TabContainer, partyName)
            end
        elseif(partyIndex == 3) then
            -- check thirdPartyShared, thirdPartyMyOffers, thirdPartyTheirOffers
            if(thirdPartyShared == nil) then
                CreateNilStateUI(TabContainer, partyName)
            else
                CreateCompareUI(TabContainer, partyName)
            end
        elseif(partyIndex == 4) then
            -- check fourthPartyShared, fourthPartyMyOffers, fourthPartyTheirOffers
            if(fourthPartyShared == nil) then
                CreateNilStateUI(TabContainer, partyName)
            else
                CreateCompareUI(TabContainer, partyName)
            end
        else
            -- something is wrong
            debugPrint("Something is wrong with the party index: " .. partyIndex)
        end

        -- Add the tab to the TabGroup
        tabGroup:AddChild(TabContainer)
        return TabContainer
    end


    local function SelectGroup(_, _, group)
        tab:ReleaseChildren()
        currentTab = group
        local index = tonumber((group:match("%d+")))
        CreatePartyTab(tab, index, UnitName("party" .. index))
    end

    SelectGroupFunction = SelectGroup

    local totalMembers = GetNumGroupMembers()
    local tabs = {}

    if totalMembers > 1 then
        for i = 1, totalMembers - 1 do
            table.insert(tabs, {text = UnitName("party" .. i), value = "tab" .. i})
        end
    end

    tab:SetTabs(tabs)
    tab:SetCallback("OnGroupSelected", SelectGroup)

    tab:SelectTab("tab1") -- Set the initial tab
    frame:AddChild(tab)
end --CreatePetCompareWindow

function PetCompareEventFrame:onLoad()
	PetCompareAddOn_Comms.Prefix = myPrefix;
	PetCompareAddOn_Comms:Init();
	PetCompareEventFrame:RegisterEvent("CHAT_MSG_PARTY")
	PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
	PetCompareEventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
	PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
	-- debugPrint("registered for messages")
end

function PetCompareEventFrame:OnEvent(event, text, ... )
    if(event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") then
		text = string.lower(text);
		if(text == "!compare") then
			local totalMembers = GetNumGroupMembers();
			if(totalMembers == 1) then
				return;
			end
			local startedPlayerName = ...;
			petCompareScore = 0;
			local myName = GetRealUnitName("player");
			print("Starting Pet Comparison Check...");
			debugPrint("debug mode is on")

			--set search filters so addon doesnt break
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED,true);
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED,true);
			--save and set sources so they are the same when the user re-opens the journal
			local numSources = C_PetJournal.GetNumPetSources();
            local filterText = C_PetJournal.GetSearchFilter();
			sourcesPreviousValue = {};
			for sourceCounter = 1, numSources, 1 do
				sourcesPreviousValue[sourceCounter] = C_PetJournal.IsPetSourceChecked(sourceCounter);
			end
			C_PetJournal.SetAllPetSourcesChecked(true);
            C_PetJournal.SetSearchFilter("");

			--save and set pet types
			local numTypes = C_PetJournal.GetNumPetTypes();
			typesPreviousValue = {};
			for typesCounter = 1, numTypes, 1 do
				typesPreviousValue[typesCounter] = C_PetJournal.IsPetTypeChecked(typesCounter);
			end
			C_PetJournal.SetAllPetTypesChecked(true);

			-- only the starting player should be sending the first message
			if(startedPlayerName == myName) then
				local myPets = {};
				local myRarities = {};
				local myLevels = {};
				local pointsAddedForPet = {};
				local  _, numOwned = C_PetJournal.GetNumPets();
				for firstPlayerCounter = 1, numOwned, 1 do
					local petID, speciesID, _, _, level, _, _, _, _, _, _, _, _, _, _, isTradeable = C_PetJournal.GetPetInfoByIndex(firstPlayerCounter);

					if(petID) then
						local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID);

                        -- calculate the pet score
						if(myPets[speciesID] ~= true) then --if this is the first of a pet
							myPets[speciesID] = true;
							myRarities[speciesID] = rarity;
							myLevels[speciesID] = level;
							pointsAddedForPet[speciesID] = 0.12 * level;
							if(rarity == 2) then --if rarity is common
								pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
							elseif(rarity == 3) then --if rarity is uncommon
								pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
							elseif(rarity == 4) then --if rarity is rare
								pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
							elseif(rarity == 5) then --if rarity is epic
								pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
							elseif(rarity == 6) then --if rarity is legendary
								pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
							end
							petCompareScore = petCompareScore + 2 + pointsAddedForPet[speciesID];

						else --if this is a duplicate
							if(isTradeable) then
								myDuplicates[speciesID] = true;
							end
							if(myRarities[speciesID] < rarity) then --if the saved pet was less rare, I need to recalculate
								petCompareScore = petCompareScore - pointsAddedForPet[speciesID];
								pointsAddedForPet[speciesID] = 0.12 * level;
								if(rarity == 2) then --if rarity is common
									pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
								elseif(rarity == 3) then --if rarity is uncommon
									pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
								elseif(rarity == 4) then --if rarity is rare
									pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
								elseif(rarity == 5) then --if rarity is epic
									pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
								elseif(rarity == 6) then --if rarity is legendary
									pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
								else
									SendChatMessage("weird rarity happened","party");
								end
								petCompareScore = petCompareScore + pointsAddedForPet[speciesID];
							elseif(myRarities[speciesID] > rarity) then --if the saved pet was more rare
								--do nothing
							else --if the saved pet is as rare as this one
								if(myLevels[speciesID] >= level)then --if the saved pet had an equal or higher level
									--do nothing
								else -- if the saved pet has a lower level, I need to recalculate
									petCompareScore = petCompareScore - pointsAddedForPet[speciesID];
									pointsAddedForPet[speciesID] = 0.12 * level;
									if(rarity == 2) then --if rarity is common
										pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 1;
									elseif(rarity == 3) then --if rarity is uncommon
										pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 2;
									elseif(rarity == 4) then --if rarity is rare
										pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 3;
									elseif(rarity == 5) then --if rarity is epic
										pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 5;
									elseif(rarity == 6) then --if rarity is legendary
										pointsAddedForPet[speciesID] = pointsAddedForPet[speciesID] + 10;
									end
									petCompareScore = petCompareScore + pointsAddedForPet[speciesID];
								end
							end
						end

					end
				end

				PetCompareAddOn_Comms:SendAMessage(myPets, "PARTY");

                PetCompareEventFrame:CreatePetCompareWindow();

                numSources = C_PetJournal.GetNumPetSources();
                for sourceCounter = 1, numSources, 1 do
                    C_PetJournal.SetPetSourceChecked(sourceCounter, sourcesPreviousValue[sourceCounter])
                end
                numTypes = C_PetJournal.GetNumPetTypes();
                for typesCounter = 1, numTypes, 1 do
                    C_PetJournal.SetPetTypeFilter(typesCounter, typesPreviousValue[typesCounter])
                end
                C_PetJournal.SetSearchFilter(filterText);
			end
		end
    elseif(event == "PLAYER_ENTERING_WORLD") then
        -- debugPrint("PEW event fired")
        PetCompareEventFrame:onLoad();
    end
end--function

PetCompareEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
