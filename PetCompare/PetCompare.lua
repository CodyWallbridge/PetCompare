local PetCompareEventFrame = CreateFrame("frame", "PetCompare Frame");
local myPrefix = "PetComparison121";
local PetCompareAddOn_Comms = {};
local petCompareAnswered = false; local petCompareScore = 0; local myDuplicates = {};
local firstPartyShared = nil; local firstPartyMyOffers = nil; local firstPartyTheirOffers = nil;
local secondPartyShared = nil; local secondPartyMyOffers = nil; local secondPartyTheirOffers = nil;
local thirdPartyShared = nil; local thirdPartyMyOffers = nil; local thirdPartyTheirOffers = nil;
local fourthPartyShared = nil; local fourthPartyMyOffers = nil; local fourthPartyTheirOffers = nil;
local sourcesPreviousValue = {};
local typesPreviousValue = {};

local partyTabs = {} -- Table to store references to tabs

-- load variables
local firstMatch = true;
local hadAMatch = false;
local initialized = false;
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
	debugPrint("sending a message via " .. channel)
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
                debugPrint("I am the sender. They are: " .. sender .. " I am: " .. myName)
                return;
            else 
                debugPrint("I am not the sender. They are: " .. sender .. " I am: " .. myName)
                debugPrint("I am answering a comparison request")
               
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
                for k,v in pairs(theirPets) do
                    if(commonPets[k] ~= true) then --go through all of theirPets, and any pet which is not shared, must be a possible offer.
                        theirOffers[k] = true;
                    end
                end
                commonPets["score"] = Round(petCompareScore);
                PetCompareAddOn_Comms:SendAMessage(commonPets, "WHISPER", sender);
                PetCompareAddOn_Comms:SendAMessage(myOffers, "WHISPER", sender);
                PetCompareAddOn_Comms:SendAMessage(theirOffers, "WHISPER", sender);
                SendChatMessage(myName .. " is done answering a request", "party");

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
            debugPrint("I got a response to my comparison request")
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
                if(theirName == sender) then --if the sender matches this party members name, 
                    if(counter == 1) then
                        if(responseTable["type"] == "common") then
                            firstPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            firstPartyMyOffers = {};
                            for k,v in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    firstPartyMyOffers[k] = true;
                                end
                            end
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            firstPartyTheirOffers = responseTable;
                        end

                    elseif(counter == 2) then
                        if(responseTable["type"] == "common") then
                            secondPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            secondPartyMyOffers = {};
                            for k,v in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    secondPartyMyOffers[k] = true;
                                end
                            end
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            secondPartyTheirOffers = responseTable;
                        end

                    elseif(counter == 3) then
                        if(responseTable["type"] == "common") then
                            thirdPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            thirdPartyMyOffers = {};
                            for k,v in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    thirdPartyMyOffers[k] = true;
                                end
                            end
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            thirdPartyTheirOffers = responseTable;
                        end

                    else
                        if(responseTable["type"] == "common") then
                            fourthPartyShared = responseTable;
                        elseif(responseTable["type"] == "startersOffers") then
                            fourthPartyMyOffers = {};
                            for k,v in pairs(responseTable) do
                                if(myDuplicates[k] == true) then --if I have a duplicate of this pet, then I can offer it
                                    fourthPartyMyOffers[k] = true;
                                end
                            end
                        elseif(responseTable["type"] == "partyMembersOffers") then
                            fourthPartyTheirOffers = responseTable;
                        end
                    end
                    break;
                end
            end
        end
	end--if
end

function PetCompareEventFrame:CreatePetCompareWindow()
     -- Callback function for OnGroupSelected
     local function SelectGroup(container, event, group)
        -- Hide all containers
        for _, tabContainer in pairs(partyTabs) do
            tabContainer.frame:Hide()
        end

        -- Show the selected container
        local selectedTab = partyTabs[group]
        if selectedTab then
            debugPrint("Showing tab: " .. group)
            selectedTab.frame:Show()
            container:AddChild(selectedTab) -- Add the selected container to the TabGroup's container
        else
            debugPrint("No tab found for: " .. group)
        end
    end
    
    -- Create the main frame container
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("PetCompare")
	frame:SetStatusText("PetCompare created by Van on Stormrage.")
	frame:SetCallback("OnClose", function(widget)
		firstPartyShared = nil; firstPartyMyOffers = nil; firstPartyTheirOffers = nil;
		secondPartyShared = nil; secondPartyMyOffers = nil; secondPartyTheirOffers = nil;
		thirdPartyShared = nil; thirdPartyMyOffers = nil; thirdPartyTheirOffers = nil;
		fourthPartyShared = nil; fourthPartyMyOffers = nil; fourthPartyTheirOffers = nil;
        partyTabs = {}
		AceGUI:Release(widget)
	end)
	-- Fill Layout - the TabGroup widget will fill the whole frame
	frame:SetLayout("Fill")

	-- Create the TabGroup
	local tab =  AceGUI:Create("TabGroup");
	petCompareScore = Round(petCompareScore);
	tab:SetTitle("My pet score: " ..petCompareScore);
	tab:SetLayout("Flow");

	local totalMembers = GetNumGroupMembers()
    local tabs = {}

    -- Setup tabs for each party member
    for i = 1, totalMembers - 1 do
        local partyName = UnitName("party" .. i)
        tabs[#tabs + 1] = { text = partyName, value = "tab" .. i }
        print("Creating tab for:", partyName, "with key: tab", i)

        -- Create a container for this tab
        local container = AceGUI:Create("SimpleGroup")
        container:SetFullWidth(true)
        container:SetFullHeight(true)
        container:SetLayout("Flow")

        -- Add default content to the container
        local PetCompareLabel = AceGUI:Create("Label")
        PetCompareLabel:SetText(partyName .. " does not have the addon so you could not compare.")
        PetCompareLabel:SetFullWidth(true)
        container:AddChild(PetCompareLabel)

        local button = AceGUI:Create("Button")
        button:SetText("Tell " .. partyName .. " that you tried to compare pets")
        button:SetCallback("OnClick", function()
            SendChatMessage("Hey " .. partyName .. " I tried to compare pets with you!", "party")
        end)
        button:SetWidth(325)
        container:AddChild(button)

        -- Store the container reference for later updates
        partyTabs["tab" .. i] = container
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
	debugPrint("registered for messages")
end

function PetCompareEventFrame:OnEvent(event, text, ... )
    if(event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") then
		text = string.lower(text);
		if(text == "!compare") then
			debugPrint("text was !compare")
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
				debugPrint("I am sending the first message.")
				local myPets = {};
				local myRarities = {};
				local myLevels = {};
				local pointsAddedForPet = {};
				local  numPets, numOwned = C_PetJournal.GetNumPets();
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
        debugPrint("PEW event fired")
        PetCompareEventFrame:onLoad();
    end
end--function

PetCompareEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
debugPrint("registered PEW")
