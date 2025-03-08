local PetCompareEventFrame = CreateFrame("frame", "PetCompare Frame");
local myPrefix = "PetComparison121";
local MyAddOn_Comms = {};
local petCompareAnswered = false; local petCompareScore = 0; local myDuplicates = {};
local firstPartyShared = nil; local firstPartyMyOffers = nil; local firstPartyTheirOffers = nil;
local secondPartyShared = nil; local secondPartyMyOffers = nil; local secondPartyTheirOffers = nil;
local thirdPartyShared = nil; local thirdPartyMyOffers = nil; local thirdPartyTheirOffers = nil;
local fourthPartyShared = nil; local fourthPartyMyOffers = nil; local fourthPartyTheirOffers = nil;
local sourcesPreviousValue = {};
local typesPreviousValue = {};

-- load variables
local firstMatch = true;
local hadAMatch = false;
local initialized = false;
local Serializer= LibStub("LibSerialize");
local Deflater = LibStub("LibDeflate");
local AceGUI = LibStub("AceGUI-3.0");
local AceComm = LibStub:GetLibrary("AceComm-3.0");

local DEBUG_MODE = true;

local function debugPrint(msg)
    if DEBUG_MODE then
        print(msg)
    end
end

function PetCompareEventFrame:onLoad()
	firstMatch = true;
	hadAMatch = false;
	initialized = false;
	Serializer=LibStub("LibSerialize");
	Deflater = LibStub("LibDeflate");
	AceGUI = LibStub("AceGUI-3.0");
	AceComm = LibStub:GetLibrary("AceComm-3.0");
	MyAddOn_Comms.Prefix = myPrefix;
	MyAddOn_Comms:Init();
	PetCompareEventFrame:RegisterEvent("CHAT_MSG_PARTY")
	PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
	PetCompareEventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
	PetCompareEventFrame:SetScript("OnEvent", PetCompareEventFrame.OnEvent);
	PetCompareEventFrame:RegisterEvent("CHAT_MSG_ADDON"); -- erase?
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
			local myName = UnitName("player") .. "-"..GetNormalizedRealmName();
			print("Starting Pet Comparison Check...");
			debugPrint("debug mode is on")

			--set search filters so addon doesnt break
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED,true);
			C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED,true);
			--save and set sources so they are the same when the user re-opens the journal
			local numSources = C_PetJournal.GetNumPetSources();
			sourcesPreviousValue = {};
			for sourceCounter = 1, numSources, 1 do
				sourcesPreviousValue[sourceCounter] = C_PetJournal.IsPetSourceChecked(sourceCounter);
			end
			C_PetJournal.SetAllPetSourcesChecked(true);

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
				initialized = true;
				local myPets = {};
				local myRarities = {};
				local myLevels = {};
				local pointsAddedForPet = {};
				local  numPets, numOwned = C_PetJournal.GetNumPets();
				for firstPlayerCounter = 1, numOwned, 1 do
					local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName, icon, petType, companionID, tooltip, description, isWild, canBattle, isTradeable = C_PetJournal.GetPetInfoByIndex(firstPlayerCounter);

					if(petID) then
						local health, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID);

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
						
					end
				end

				MyAddOn_Comms:SendAMessage(myPets);

				C_Timer.After(5, function()
					SendChatMessage("setting initialized to false", "party");
					initialized = false;
				end)

				C_Timer.After(1, function()
					PetCompareEventFrame:CreatePetCompareWindow();
					numSources = C_PetJournal.GetNumPetSources();
					for sourceCounter = 1, numSources, 1 do
						C_PetJournal.SetPetSourceChecked(sourceCounter, sourcesPreviousValue[sourceCounter])
					end
					numTypes = C_PetJournal.GetNumPetTypes();
					for typesCounter = 1, numTypes, 1 do
						C_PetJournal.SetPetTypeFilter(typesCounter, typesPreviousValue[typesCounter])
					end
				end)
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

function MyAddOn_Comms:Init()
    AceComm:Embed(self);
    self:RegisterComm(self.Prefix, "OnCommReceived");
end

function MyAddOn_Comms:OnCommReceived(passedPrefix, msg, distribution, sender)
	if (passedPrefix == myPrefix) then
		local myName = UnitName("player");
		if(sender ~= myName) then
			debugPrint("I am not the sender. They are: " .. sender .. " I am: " .. myName)
			if(initialized == true) then --if im the person who started the comparison
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
					local name, realm = UnitName(index);
					if(realm) then
						name = name .. "-" .. realm;
					end
					if(name == sender) then --if the sender matches this party members name, 
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

			else--if im the person who is answering the comparison
				debugPrint("I am answering a comparison request")
				if(petCompareAnswered == false) then --if i have not answered yet
					debugPrint("I have not answered yet")
					petCompareScore = 0;
					local  numPets, numOwned = C_PetJournal.GetNumPets();
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
						local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName, icon, petType, companionID, tooltip = C_PetJournal.GetPetInfoByIndex(secondPlayerCounter);
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

							local health, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID);
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
					MyAddOn_Comms:SendAMessage(commonPets);
					MyAddOn_Comms:SendAMessage(myOffers);
					MyAddOn_Comms:SendAMessage(theirOffers);
					SendChatMessage(myName .. " is done answering a request", "party");
					local numSources = C_PetJournal.GetNumPetSources();
					for sourceCounter = 1, numSources, 1 do
						C_PetJournal.SetPetSourceChecked(sourceCounter, sourcesPreviousValue[sourceCounter])
					end
					numTypes = C_PetJournal.GetNumPetTypes();
					for typesCounter = 1, numTypes, 1 do
						C_PetJournal.SetPetTypeFilter(typesCounter, typesPreviousValue[typesCounter])
					end
					petCompareAnswered = true;
					C_Timer.After(3, function() 
						petCompareAnswered = false;
					end)
				end
			end
		else -- debug only
			debugPrint("I am the sender. They are: " .. sender .. " I am: " .. myName)
		end --if sender != target
	end--if
end

function MyAddOn_Comms:SendAMessage(myPets)
	local serialized = Serializer:Serialize(myPets); 
	local compressed = Deflater:CompressDeflate(serialized);
	local encoded = Deflater:EncodeForWoWAddonChannel(compressed)
	--SendChatMessage("sending message","party");
	debugPrint("sending a message")
	self:SendCommMessage(myPrefix, encoded, "PARTY");
end

function PetCompareEventFrame:CreatePetCompareWindow()
	local function DrawGroup1(container)
		local function DrawSharedTab(container)
			local name = UnitName("party1");
			local sharedScrollcontainer = AceGUI:Create("SimpleGroup");
			sharedScrollcontainer:SetFullWidth(true);
			sharedScrollcontainer:SetFullHeight(true);
			sharedScrollcontainer:SetLayout("Fill");

			container:AddChild(sharedScrollcontainer);

			local sharedScroll = AceGUI:Create("ScrollFrame");
			sharedScroll:SetLayout("Flow");
			sharedScrollcontainer:AddChild(sharedScroll);

			local count = 0;
			for k,v in pairs(firstPartyShared) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(firstPartyShared) do
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

		local function DrawMyOffersTab(container)
			local name = UnitName("party1");
			local myOffersScrollContainer = AceGUI:Create("SimpleGroup");
			myOffersScrollContainer:SetFullWidth(true);
			myOffersScrollContainer:SetFullHeight(true);
			myOffersScrollContainer:SetLayout("Fill");

			container:AddChild(myOffersScrollContainer);

			local myOffersScroll = AceGUI:Create("ScrollFrame");
			myOffersScroll:SetLayout("Flow");
			myOffersScrollContainer:AddChild(myOffersScroll);

			local count = 0;
			for k,v in pairs(firstPartyMyOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(firstPartyMyOffers) do
					if(k == "score") then
						--do nothing
					elseif(k == "type") then
						--do nothing
					else
						speciesName, speciesIcon = C_PetJournal.GetPetInfoBySpeciesID(k);
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

		local function DrawTheirOffersTab(container)
			local name = UnitName("party1");
			local theirOffersScrollContainer = AceGUI:Create("SimpleGroup");
			theirOffersScrollContainer:SetFullWidth(true);
			theirOffersScrollContainer:SetFullHeight(true);
			theirOffersScrollContainer:SetLayout("Fill");

			container:AddChild(theirOffersScrollContainer);

			local theirOffersScroll = AceGUI:Create("ScrollFrame");
			theirOffersScroll:SetLayout("Flow");
			theirOffersScrollContainer:AddChild(theirOffersScroll);

			local count = 0;
			for k,v in pairs(firstPartyTheirOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(firstPartyTheirOffers) do
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

		-- Callback function for OnGroupSelected
		local function SelectPetGroup(container, event, group)
		   container:ReleaseChildren();
		   if group == "sharedPets" then
			  DrawSharedTab(container);
		   elseif group == "myOffers" then
			  DrawMyOffersTab(container);
		   elseif group == "theirOffers" then
			  DrawTheirOffersTab(container);
		   end
		end

		local name = UnitName("party1");

		if(firstPartyShared) then --if they have the addon
			local PetCompareScoreLabel = AceGUI:Create("Label");
			PetCompareScoreLabel:SetText(name .."'s pet score: " .. firstPartyShared["score"] );
			if(petCompareScore > firstPartyShared["score"]) then -- if my score is higher
				PetCompareScoreLabel:SetColor(0,255,0);
			elseif(petCompareScore == firstPartyShared["score"]) then --if we have the same score
				PetCompareScoreLabel:SetColor(0,255,42);
			else --if their score is higher
				PetCompareScoreLabel:SetColor(255,0,0);
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
		else
			local PetCompareLabel = AceGUI:Create("Label");
			PetCompareLabel:SetText(name .. " does not have the addon so you could not compare.")
			PetCompareLabel:SetFullWidth(true)
			container:AddChild(PetCompareLabel);

			local button = AceGUI:Create("Button");
			button:SetText("Tell " .. name .. " that you tried to compare pets");
			button:SetCallback("OnClick",
			function()
				SendChatMessage("Hey " .. name .. " I tried to compare pets with you!", "party");
			end)
			button:SetWidth(325);
			container:AddChild(button);
		end
	end

	-- function that draws the widgets for the second tab
	local function DrawGroup2(container)
		local function DrawSharedTab(container)
			local name = UnitName("party2");
			local sharedScrollcontainer = AceGUI:Create("SimpleGroup");
			sharedScrollcontainer:SetFullWidth(true);
			sharedScrollcontainer:SetFullHeight(true);
			sharedScrollcontainer:SetLayout("Fill");

			container:AddChild(sharedScrollcontainer);

			local sharedScroll = AceGUI:Create("ScrollFrame");
			sharedScroll:SetLayout("Flow");
			sharedScrollcontainer:AddChild(sharedScroll);

			local count = 0;
			for k,v in pairs(secondPartyShared) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(secondPartyShared) do
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

		local function DrawMyOffersTab(container)
			local name = UnitName("party2");
			local myOffersScrollContainer = AceGUI:Create("SimpleGroup");
			myOffersScrollContainer:SetFullWidth(true);
			myOffersScrollContainer:SetFullHeight(true);
			myOffersScrollContainer:SetLayout("Fill");

			container:AddChild(myOffersScrollContainer);

			local myOffersScroll = AceGUI:Create("ScrollFrame");
			myOffersScroll:SetLayout("Flow");
			myOffersScrollContainer:AddChild(myOffersScroll);

			local count = 0;
			for k,v in pairs(secondPartyMyOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(secondPartyMyOffers) do
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

		local function DrawTheirOffersTab(container)
			local name = UnitName("party2");
			local theirOffersScrollContainer = AceGUI:Create("SimpleGroup");
			theirOffersScrollContainer:SetFullWidth(true);
			theirOffersScrollContainer:SetFullHeight(true);
			theirOffersScrollContainer:SetLayout("Fill");

			container:AddChild(theirOffersScrollContainer);

			local theirOffersScroll = AceGUI:Create("ScrollFrame");
			theirOffersScroll:SetLayout("Flow");
			theirOffersScrollContainer:AddChild(theirOffersScroll);

			local count = 0;
			for k,v in pairs(secondPartyTheirOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(secondPartyTheirOffers) do
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

		-- Callback function for OnGroupSelected
		local function SelectPetGroup(container, event, group)
		   container:ReleaseChildren();
		   if group == "sharedPets" then
			  DrawSharedTab(container);
		   elseif group == "myOffers" then
			  DrawMyOffersTab(container);
		   elseif group == "theirOffers" then
			  DrawTheirOffersTab(container);
		   end
		end

		local name = UnitName("party2");

		if(secondPartyShared) then --if they have the addon
			local PetCompareScoreLabel = AceGUI:Create("Label");
			PetCompareScoreLabel:SetText(name.."'s pet score: " .. secondPartyShared["score"] );
			if(petCompareScore > secondPartyShared["score"]) then -- if my score is higher
				PetCompareScoreLabel:SetColor(0,255,0);
			elseif(petCompareScore == secondPartyShared["score"]) then --if we have the same score
				PetCompareScoreLabel:SetColor(0,255,42);
			else --if their score is higher
				PetCompareScoreLabel:SetColor(255,0,0);
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
			
		else
			local PetCompareLabel = AceGUI:Create("Label");
			PetCompareLabel:SetText(name .. " does not have the addon so you could not compare.")
			PetCompareLabel:SetFullWidth(true)
			container:AddChild(PetCompareLabel);

			local button = AceGUI:Create("Button");
			button:SetText("Tell " .. name .. " that you tried to compare pets");
			button:SetCallback("OnClick", 
			function() 
				SendChatMessage("Hey " .. name .. " I tried to compare pets with you!", "party");
			end)
			button:SetWidth(325);
			container:AddChild(button);
		end
	end

	-- function that draws the widgets for the second tab
	local function DrawGroup3(container)
		local function DrawSharedTab(container)
			local name = UnitName("party2");
			local sharedScrollcontainer = AceGUI:Create("SimpleGroup");
			sharedScrollcontainer:SetFullWidth(true);
			sharedScrollcontainer:SetFullHeight(true);
			sharedScrollcontainer:SetLayout("Fill");

			container:AddChild(sharedScrollcontainer);

			local sharedScroll = AceGUI:Create("ScrollFrame");
			sharedScroll:SetLayout("Flow");
			sharedScrollcontainer:AddChild(sharedScroll);

			local count = 0;
			for k,v in pairs(thirdPartyShared) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(thirdPartyShared) do
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

		local function DrawMyOffersTab(container)
			local name = UnitName("party3");
			local myOffersScrollContainer = AceGUI:Create("SimpleGroup");
			myOffersScrollContainer:SetFullWidth(true);
			myOffersScrollContainer:SetFullHeight(true);
			myOffersScrollContainer:SetLayout("Fill");

			container:AddChild(myOffersScrollContainer);

			local myOffersScroll = AceGUI:Create("ScrollFrame");
			myOffersScroll:SetLayout("Flow");
			myOffersScrollContainer:AddChild(myOffersScroll);

			local count = 0;
			for k,v in pairs(thirdPartyMyOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(thirdPartyMyOffers) do
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

		local function DrawTheirOffersTab(container)
			local name = UnitName("party3");
			local theirOffersScrollContainer = AceGUI:Create("SimpleGroup");
			theirOffersScrollContainer:SetFullWidth(true);
			theirOffersScrollContainer:SetFullHeight(true);
			theirOffersScrollContainer:SetLayout("Fill");

			container:AddChild(theirOffersScrollContainer);

			local theirOffersScroll = AceGUI:Create("ScrollFrame");
			theirOffersScroll:SetLayout("Flow");
			theirOffersScrollContainer:AddChild(theirOffersScroll);

			local count = 0;
			for k,v in pairs(thirdPartyTheirOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(thirdPartyTheirOffers) do
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

		-- Callback function for OnGroupSelected
		local function SelectPetGroup(container, event, group)
		   container:ReleaseChildren();
		   if group == "sharedPets" then
			  DrawSharedTab(container);
		   elseif group == "myOffers" then
			  DrawMyOffersTab(container);
		   elseif group == "theirOffers" then
			  DrawTheirOffersTab(container);
		   end
		end

		local name = UnitName("party3");

		if(thirdPartyShared) then --if they have the addon
			local PetCompareScoreLabel = AceGUI:Create("Label");
			PetCompareScoreLabel:SetText(name .. "'s pet score: " .. thirdPartyShared["score"] );
			if(petCompareScore > thirdPartyShared["score"]) then -- if my score is higher
				PetCompareScoreLabel:SetColor(0,255,0);
			elseif(petCompareScore == thirdPartyShared["score"]) then --if we have the same score
				PetCompareScoreLabel:SetColor(0,255,42);
			else --if their score is higher
				PetCompareScoreLabel:SetColor(255,0,0);
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
		else
			local PetCompareLabel = AceGUI:Create("Label");
			PetCompareLabel:SetText(name .. " does not have the addon so you could not compare.")
			PetCompareLabel:SetFullWidth(true)
			container:AddChild(PetCompareLabel);

			local button = AceGUI:Create("Button");
			button:SetText("Tell " .. name .. " that you tried to compare pets");
			button:SetCallback("OnClick", 
			function() 
				SendChatMessage("Hey " .. name .. " I tried to compare pets with you!", "party");
			end)
			button:SetWidth(325);
			container:AddChild(button);
		end
	end

	-- function that draws the widgets for the second tab
	local function DrawGroup4(container)
		local function DrawSharedTab(container)
			local name = UnitName("party4");
			local sharedScrollcontainer = AceGUI:Create("SimpleGroup");
			sharedScrollcontainer:SetFullWidth(true);
			sharedScrollcontainer:SetFullHeight(true);
			sharedScrollcontainer:SetLayout("Fill");

			container:AddChild(sharedScrollcontainer);

			local sharedScroll = AceGUI:Create("ScrollFrame");
			sharedScroll:SetLayout("Flow");
			sharedScrollcontainer:AddChild(sharedScroll);

			local count = 0;
			for k,v in pairs(fourthPartyShared) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(fourthPartyShared) do
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

		local function DrawMyOffersTab(container)
			local name = UnitName("party4");
			local myOffersScrollContainer = AceGUI:Create("SimpleGroup");
			myOffersScrollContainer:SetFullWidth(true);
			myOffersScrollContainer:SetFullHeight(true);
			myOffersScrollContainer:SetLayout("Fill");

			container:AddChild(myOffersScrollContainer);

			local myOffersScroll = AceGUI:Create("ScrollFrame");
			myOffersScroll:SetLayout("Flow");
			myOffersScrollContainer:AddChild(myOffersScroll);

			local count = 0;
			for k,v in pairs(fourthPartyMyOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(fourthPartyMyOffers) do
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

		local function DrawTheirOffersTab(container)
			local name = UnitName("party4");
			local theirOffersScrollContainer = AceGUI:Create("SimpleGroup");
			theirOffersScrollContainer:SetFullWidth(true);
			theirOffersScrollContainer:SetFullHeight(true);
			theirOffersScrollContainer:SetLayout("Fill");

			container:AddChild(theirOffersScrollContainer);

			local theirOffersScroll = AceGUI:Create("ScrollFrame");
			theirOffersScroll:SetLayout("Flow");
			theirOffersScrollContainer:AddChild(theirOffersScroll);

			local count = 0;
			for k,v in pairs(fourthPartyTheirOffers) do
				if(k == "score") then
					--do nothing
				elseif(k == "type") then
					--do nothing
				else
					count = count +1;
				end
			end
			if(count > 0) then
				for k,v in pairs(fourthPartyTheirOffers) do
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

		-- Callback function for OnGroupSelected
		local function SelectPetGroup(container, event, group)
		   container:ReleaseChildren();
		   if group == "sharedPets" then
			  DrawSharedTab(container);
		   elseif group == "myOffers" then
			  DrawMyOffersTab(container);
		   elseif group == "theirOffers" then
			  DrawTheirOffersTab(container);
		   end
		end


		local name = UnitName("party4");

		if(fourthPartyShared) then
			local PetCompareScoreLabel = AceGUI:Create("Label");
			PetCompareScoreLabel:SetText(name .. "'s pet score: " .. fourthPartyShared["score"] );
			if(petCompareScore > fourthPartyShared["score"]) then -- if my score is higher
				PetCompareScoreLabel:SetColor(0,255,0);
			elseif(petCompareScore == fourthPartyShared["score"]) then --if we have the same score
				PetCompareScoreLabel:SetColor(0,255,42);
			else --if their score is higher
				PetCompareScoreLabel:SetColor(255,0,0);
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
		else
			local PetCompareLabel = AceGUI:Create("Label");
			PetCompareLabel:SetText(name .. " does not have the addon so you could not compare.")
			PetCompareLabel:SetFullWidth(true)
			container:AddChild(PetCompareLabel);

			local button = AceGUI:Create("Button");
			button:SetText("Tell " .. name .. " that you tried to compare pets");
			button:SetCallback("OnClick", 
			function() 
				SendChatMessage("Hey " .. name .. " I tried to compare pets with you!", "party");
			end)
			button:SetWidth(325);
			container:AddChild(button);
		end
	end

	-- Callback function for OnGroupSelected
	local function SelectGroup(container, event, group)
	   container:ReleaseChildren();
	   if group == "tab1" then
		  DrawGroup1(container)
	   elseif group == "tab2" then
		  DrawGroup2(container)
	   elseif group == "tab3" then
		  DrawGroup3(container)
	   elseif group == "tab4" then
		  DrawGroup4(container)
	   end
	end

	-- Create the frame container
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

	local totalMembers = GetNumGroupMembers();

	-- Setup which tabs to show
	if(totalMembers == 2) then
		local party1Name = UnitName("party1");
		tab:SetTabs( { {text=party1Name, value="tab1"} } )

	elseif(totalMembers == 3) then
		local party1Name = UnitName("party1");
		local party2Name = UnitName("party2")
		tab:SetTabs( { {text=party1Name, value="tab1"}, {text=party2Name, value="tab2"} } )

	elseif(totalMembers == 4) then
		local party1Name = UnitName("party1");
		local party2Name = UnitName("party2");
		local party3Name = UnitName("party3");
		tab:SetTabs( { {text=party1Name, value="tab1"}, {text=party2Name, value="tab2"}, {text=party3Name, value="tab3"} } )

	elseif(totalMembers == 5) then
		local party1Name = UnitName("party1");
		local party2Name = UnitName("party2");
		local party3Name = UnitName("party3");
		local party4Name = UnitName("party4");
		tab:SetTabs( { {text=party1Name, value="tab1"}, {text=party2Name, value="tab2"}, {text=party3Name, value="tab3"}, {text=party4Name, value="tab4"} } )
	end

	-- Register callback
	tab:SetCallback("OnGroupSelected", SelectGroup)
	-- Set initial Tab (this will fire the OnGroupSelected callback)
	tab:SelectTab("tab1")

	-- add to the frame container
	frame:AddChild(tab)
end--CreatePetCompareWindow
