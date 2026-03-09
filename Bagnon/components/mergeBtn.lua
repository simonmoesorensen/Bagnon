--[[
	mergeBtn.lua
		A button that merges partial stacks of identical items in Bagnon
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local MergeBtn = Bagnon.Classy:New('Button')
Bagnon.MergeBtn = MergeBtn

local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE / 36)

local moves = {};
local frame = CreateFrame("Frame");
local t = 0;
local current = nil;
local isGuildBankMerge = false;

local function GetIDFromLink(link)
	return link and tonumber(string.match(link, "item:(%d+)"));
end

local function GetAscensionBankType()
	local detectedPersonal = nil
	local detectedRealm = nil

	if HasJsonCacheData("BANK_PERMISSIONS_PAYLOAD", 0) then
		local json = GetJsonCacheData("BANK_PERMISSIONS_PAYLOAD", 0)
		if json then
			local jsonObject = C_Serialize:FromJSON(json)
			if jsonObject then
				detectedPersonal = jsonObject.IsPersonalBank
				detectedRealm = jsonObject.IsRealmBank
			end
		end
	end

	if not detectedPersonal and not detectedRealm then
		local numTabs = GetNumGuildBankTabs()
		local firstTabName = numTabs > 0 and GetGuildBankTabInfo(1) or nil
		detectedPersonal = (firstTabName == "Personal Bank")
		detectedRealm = (firstTabName == "Realm Bank")
	end

	if detectedPersonal then
		return "personal"
	elseif detectedRealm then
		return "realm"
	else
		return nil
	end
end

local function DoGuildBankMoves()
	while (current ~= nil or #moves > 0) do
		if current ~= nil then
			if CursorHasItem() then
				local _, id = GetCursorInfo();
				if (current.id == id) then
					PickupGuildBankItem(current.targettab, current.targetslot);
					return;
				else
					moves = {};
					current = nil;
					frame:Hide();
					return;
				end
			else
				if current.picked then
					current = nil;
				else
					PickupGuildBankItem(current.sourcetab, current.sourceslot);
					if CursorHasItem() then
						current.picked = true;
					end
					return;
				end
			end
		else
			if (#moves > 0) then
				current = table.remove(moves, 1);
				current.picked = false;
				if (current.sourcetab ~= nil) then
					PickupGuildBankItem(current.sourcetab, current.sourceslot);
					if CursorHasItem() == false then
						return;
					end
					current.picked = true;
					PickupGuildBankItem(current.targettab, current.targetslot);
					return;
				end
			end
		end
	end
	frame:Hide();
	isGuildBankMerge = false;
end

local function DoContainerMoves()
	while (current ~= nil or #moves > 0) do
		if current ~= nil then
			if CursorHasItem() then
				local _, id = GetCursorInfo();
				if (current.id == id) then
					PickupContainerItem(current.targetbag, current.targetslot);
					return;
				else
					moves = {};
					current = nil;
					frame:Hide();
					return;
				end
			else
				if current.picked then
					current = nil;
				else
					PickupContainerItem(current.sourcebag, current.sourceslot);
					if CursorHasItem() then
						current.picked = true;
					end
					return;
				end
			end
		else
			if (#moves > 0) then
				current = table.remove(moves, 1);
				current.picked = false;
				if (current.sourcebag ~= nil) then
					PickupContainerItem(current.sourcebag, current.sourceslot);
					if CursorHasItem() == false then
						return;
					end
					current.picked = true;
					PickupContainerItem(current.targetbag, current.targetslot);
					return;
				end
			end
		end
	end
	frame:Hide();
end

local function DoMoves()
	if isGuildBankMerge then
		DoGuildBankMoves()
	else
		DoContainerMoves()
	end
end

local function BeginMerge()
	current = nil;
	moves = {};
	ClearCursor();
end

local function BuildContainerMergeMoves(allItems)
	local itemStacks = {};

	for _, item in ipairs(allItems) do
		if item.id ~= nil then
			if not itemStacks[item.id] then
				itemStacks[item.id] = {};
			end
			table.insert(itemStacks[item.id], item);
		end
	end

	for id, stacks in pairs(itemStacks) do
		if #stacks > 1 then
			local _, _, _, _, _, _, _, maxStack = GetItemInfo(id);
			maxStack = maxStack or 1;
			if maxStack > 1 then
				local dst = 1;
				local src = 2;
				while src <= #stacks do
					while dst < src and stacks[dst].count >= maxStack do
						dst = dst + 1;
					end
					if dst < src and stacks[src].count > 0 then
						local move = {};
						move.id = id;
						move.sourcebag = stacks[src].bag;
						move.sourceslot = stacks[src].slot;
						move.targetbag = stacks[dst].bag;
						move.targetslot = stacks[dst].slot;
						table.insert(moves, move);

						local space = maxStack - stacks[dst].count;
						local transferred = math.min(space, stacks[src].count);
						stacks[dst].count = stacks[dst].count + transferred;
						stacks[src].count = stacks[src].count - transferred;

						if stacks[src].count <= 0 then
							src = src + 1;
						end
					else
						src = src + 1;
					end
				end
			end
		end
	end
end

local function BuildGuildBankMergeMoves(allItems)
	local itemStacks = {};

	for _, item in ipairs(allItems) do
		if item.id ~= nil then
			if not itemStacks[item.id] then
				itemStacks[item.id] = {};
			end
			table.insert(itemStacks[item.id], item);
		end
	end

	for id, stacks in pairs(itemStacks) do
		if #stacks > 1 then
			local _, _, _, _, _, _, _, maxStack = GetItemInfo(id);
			maxStack = maxStack or 1;
			if maxStack > 1 then
				local dst = 1;
				local src = 2;
				while src <= #stacks do
					while dst < src and stacks[dst].count >= maxStack do
						dst = dst + 1;
					end
					if dst < src and stacks[src].count > 0 then
						local move = {};
						move.id = id;
						move.sourcetab = stacks[src].tab;
						move.sourceslot = stacks[src].slot;
						move.targettab = stacks[dst].tab;
						move.targetslot = stacks[dst].slot;
						table.insert(moves, move);

						local space = maxStack - stacks[dst].count;
						local transferred = math.min(space, stacks[src].count);
						stacks[dst].count = stacks[dst].count + transferred;
						stacks[src].count = stacks[src].count - transferred;

						if stacks[src].count <= 0 then
							src = src + 1;
						end
					else
						src = src + 1;
					end
				end
			end
		end
	end
end

local function CreateBagFromID(bagID)
	local numSlots = GetContainerNumSlots(bagID);
	local bag = {};

	for i = 1, numSlots, 1 do
		local item = {};
		local _, count, _, _, _, _, link = GetContainerItemInfo(bagID, i);
		item.bag = bagID;
		item.slot = i;
		item.id = GetIDFromLink(link);
		if (item.id ~= nil) then
			item.count = count;
		end
		table.insert(bag, item);
	end
	return bag;
end

local function CreateGuildBankTabItems(tabID)
	local items = {};
	local numSlots = 98;

	for i = 1, numSlots, 1 do
		local item = {};
		local texture, count, locked = GetGuildBankItemInfo(tabID, i);
		local link = GetGuildBankItemLink(tabID, i);

		item.tab = tabID;
		item.slot = i;
		item.id = GetIDFromLink(link);
		if (item.id ~= nil) then
			item.count = count or 1;
		end
		table.insert(items, item);
	end
	return items;
end

frame:SetScript("OnUpdate", function()
	t = t + arg1;
	if t > 0.03 then
		t = 0
		DoMoves();
	end
end)
frame:Hide();

--[[ Constructor ]] --
function MergeBtn:New(frameID, parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('anyUp')

	local nt = b:CreateTexture()
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	b:SetNormalTexture(nt)

	local pt = b:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(b)
	b:SetPushedTexture(pt)

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local icon = b:CreateTexture()
	icon:SetAllPoints(b)
	icon:SetTexture([[Interface\Icons\INV_Misc_GroupNeedMore]])

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)
	b:SetFrameID(frameID)

	return b
end

--[[ Frame Events ]] --
function MergeBtn:OnClick()
	local allItems = {};

	if self.frameID == "inventory" then
		isGuildBankMerge = false;
		for i = 0, NUM_BAG_FRAMES, 1 do
			local bag = CreateBagFromID(i);
			for j = 1, #bag, 1 do
				table.insert(allItems, bag[j]);
			end
		end
	elseif self.frameID == "bank" then
		isGuildBankMerge = false;
		local bag = CreateBagFromID(-1);
		for j = 1, #bag, 1 do
			table.insert(allItems, bag[j]);
		end

		for i = NUM_BAG_FRAMES+1, NUM_BAG_FRAMES + NUM_BANKBAGSLOTS, 1 do
			local bag = CreateBagFromID(i);
			for j = 1, #bag, 1 do
				table.insert(allItems, bag[j]);
			end
		end
	elseif self.frameID == "guildbank" then
		isGuildBankMerge = true;

		local currentTab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 0

		if currentTab and currentTab > 0 then
			local bankType = GetAscensionBankType()
			local canMerge = false

			if bankType == "personal" or bankType == "realm" then
				canMerge = true
			else
				local _, _, canView, canDeposit, _, remainingWithdrawals = GetGuildBankTabInfo(currentTab)
				if canDeposit and (remainingWithdrawals == -1 or remainingWithdrawals > 0) then
					canMerge = true
				end
			end

			if canMerge then
				local tabItems = CreateGuildBankTabItems(currentTab)
				for j = 1, #tabItems, 1 do
					table.insert(allItems, tabItems[j]);
				end
			else
				return
			end
		else
			return
		end
	end

	if #allItems == 0 then
		return
	end

	BeginMerge();

	if isGuildBankMerge then
		BuildGuildBankMergeMoves(allItems);
	else
		BuildContainerMergeMoves(allItems);
	end

	if #moves > 0 then
		frame:Show();
	end
end

function MergeBtn:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end
	self:UpdateTooltip()
end

function MergeBtn:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

--[[ Update Methods ]] --

function MergeBtn:UpdateTooltip()
	if GameTooltip:IsOwned(self) then
		GameTooltip:SetText(L.TipShowMergeBtn)
	end
end

--[[ Properties ]] --

function MergeBtn:SetFrameID(frameID)
	if self:GetFrameID() ~= frameID then
		self.frameID = frameID
	end
end

function MergeBtn:GetFrameID()
	return self.frameID
end
