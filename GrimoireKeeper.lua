local _, class = UnitClass('player')
if class ~= 'WARLOCK' then return end

local _G = getfenv()
local gsub = string.gsub
local find = string.find
local pairs = pairs
local tonumber = tonumber
local SPELLS_PER_PAGE = _G.SPELLS_PER_PAGE
local MERCHANT_ITEMS_PER_PAGE = _G.MERCHANT_ITEMS_PER_PAGE
local CreateFrame = _G.CreateFrame
local HasPetUI = _G.HasPetUI
local GetSpellName = _G.GetSpellName
local GetSpellTexture = _G.GetSpellTexture
local GetMerchantNumItems = _G.GetMerchantNumItems
local GetMerchantItemLink = _G.GetMerchantItemLink
local GetMerchantItemInfo = _G.GetMerchantItemInfo

local DemonSpellTable = {} -- table of learned demon spells
local GrimoireDB = {} -- table of learned grimoires
local GrimoireTable = {
  -- [spell texture] = {grimoire id by ranks}
  ['Imp'] = {
    ['Spell_Fire_FireBolt']             = {nil,     '16302', '16316', '16317', '16318', '16319', '16320'}, -- Firebolt
    ['Spell_Shadow_BloodBoil']          = {'16321', '16322', '16323', '16324', '16325'}, -- Blood Pact
    ['Spell_Fire_FireArmor']            = {'16326', '16327', '16328', '16329', '16330'}, -- Fire Shield
    ['Spell_Shadow_ImpPhaseShift']      = {'16331'} -- Phase Shift
  },
  ['Voidwalker'] = {
    ['Spell_Shadow_GatherShadows']      = {nil,     '16346', '16347', '16348', '16349', '16350'}, -- Torment
    ['Spell_Shadow_SacrificialShield']  = {'16351', '16352', '16353', '16354', '16355', '16356'}, -- Sacrifice
    ['Spell_Shadow_AntiShadow']         = {'16357', '16358', '16359', '16360', '16361', '16362'}, -- Consume Shadows
    ['Spell_Shadow_BlackPlague']        = {'16363', '16364', '16365', '16366'} -- Suffering
  },
  ['Succubus'] = {
    ['Spell_Shadow_Curse']              = {nil,     '16368', '16371', '16372', '16373', '16374'}, -- Lash of Pain
    ['Spell_Shadow_SoothingKiss']       = {'16375', '16376', '16377', '16378'}, -- Soothing Kiss
    ['Spell_Shadow_MindSteal']          = {'16379'}, -- Seduction
    ['Spell_Magic_LesserInvisibilty']   = {'16380'} -- Lesser Invisibility
  },
  ['Felhunter'] = {
    ['Spell_Nature_Purge']              = {nil,     '16381', '16382', '16383'}, -- Devour Magic
    ['Spell_Shadow_LifeDrain']          = {'16384', '16385', '16386', '16387'}, -- Tainted Blood
    ['Spell_Shadow_MindRot']            = {'16388', '16389'}, -- Spell Lock
    ['Spell_Shadow_AuraOfDarkness']     = {'16390'} -- Paranoia
  }
}

local GrimoireKeeper = CreateFrame('Frame')
GrimoireKeeper:SetScript('OnEvent', function()
  if not this[event] then return end
  this[event](this)
end)

GrimoireKeeper:RegisterEvent('MERCHANT_SHOW')
GrimoireKeeper:RegisterEvent('MERCHANT_CLOSED')
GrimoireKeeper:RegisterEvent('PET_BAR_UPDATE')
GrimoireKeeper.hooks = {}

function GrimoireKeeper:MERCHANT_SHOW()
  if MerchantItem1ItemButton:GetRegions():GetTexture() == 'Interface\\Icons\\INV_Misc_Book_06' then
    self.isDemonVendor = true
  end
  if not self.isDemonVendor or not self.demonType or not HasPetUI() then return end

  self:ScanDemonSpells()
  self:UpdateGrimoireData()
  MerchantFrame_UpdateMerchantInfo()
end

function GrimoireKeeper:MERCHANT_CLOSED()
  self.isDemonVendor = nil
end

function GrimoireKeeper:PET_BAR_UPDATE()
  self.demonType = self:GetDemonFamily()

  if MerchantFrame:IsShown() and self.isDemonVendor then
    self:ScanDemonSpells()
    self:UpdateGrimoireData()
    MerchantFrame_UpdateMerchantInfo()
  end
end

function GrimoireKeeper:isValidGrimoire(itemID)
  for _, GrimoireIDs in pairs(GrimoireTable[self.demonType]) do
    for _, GrimoireID in pairs(GrimoireIDs) do
      if itemID == GrimoireID then return true end
    end
  end
end

function GrimoireKeeper:GetDemonFamily()
  for spellIndex = 1, SPELLS_PER_PAGE do
    local spellTexture = GetSpellTexture(spellIndex, BOOKTYPE_PET)
    if not spellTexture then return end

    spellTexture = gsub(spellTexture, 'Interface\\Icons\\', '')
    for demonFamily, textures in pairs(GrimoireTable) do
      if textures[spellTexture] then
        return demonFamily
      end
    end
  end
end

function GrimoireKeeper:ScanDemonSpells()
  DemonSpellTable = {}
  for spellIndex = 1, SPELLS_PER_PAGE do
    local spellTexture = GetSpellTexture(spellIndex, BOOKTYPE_PET)
    if not spellTexture then return end

    spellTexture = gsub(spellTexture, 'Interface\\Icons\\', '')
    local _, rank = GetSpellName(spellIndex, BOOKTYPE_PET)
    _, _, rank = find(rank, '(%d)')
    if not rank then rank = 1 end
    DemonSpellTable[spellTexture] = tonumber(rank)
  end
end

function GrimoireKeeper:UpdateGrimoireData()
  GrimoireDB = {}
  for spellTexture, spellRank in pairs(DemonSpellTable) do
    -- Check if the spellTexture exists in the table for this demon type
    if GrimoireTable[self.demonType] and GrimoireTable[self.demonType][spellTexture] then
      for i=1, spellRank do
        -- Check if the index exists before trying to access it
        if GrimoireTable[self.demonType][spellTexture][i] then
          local GrimoireID = GrimoireTable[self.demonType][spellTexture][i]
          if GrimoireID then
            GrimoireDB[GrimoireID] = true
          end
        end
      end
    else
      -- Debug info if needed
      -- DEFAULT_CHAT_FRAME:AddMessage("Missing spell texture: " .. spellTexture .. " for " .. (self.demonType or "unknown demon"))
    end
  end
end

GrimoireKeeper.hooks.MerchantFrame_UpdateMerchantInfo = MerchantFrame_UpdateMerchantInfo
function MerchantFrame_UpdateMerchantInfo()
  GrimoireKeeper.hooks.MerchantFrame_UpdateMerchantInfo()
  if not GrimoireKeeper.isDemonVendor or not GrimoireKeeper.demonType or not HasPetUI() then return end
  for i=1, MERCHANT_ITEMS_PER_PAGE do
    local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
    local itemButton = _G['MerchantItem'..i..'ItemButton']
    local merchantButton = _G['MerchantItem'..i]
    itemButton:SetScript("OnClick", MerchantItemButton_OnClick) -- return the possibility of buying the items (when updating MerchantFrame)
    if index > GetMerchantNumItems() then return end
    local _, _, _, _, _, isUsable = GetMerchantItemInfo(index)
    local link = GetMerchantItemLink(index)
    if not link then return end
    local _, _, itemID = find(link, 'item:(%d+):')

    local ir, ig, ib -- color for itemButton
    local mr, mg, mb -- color for merchantButton
    if not GrimoireKeeper:isValidGrimoire(itemID) then -- if grimoire is not suitable for the current demon
      mr, mg, mb, ir, ig, ib = .5, 0, 0 -- red color
      itemButton:SetScript("OnClick", nil) -- disabling item buying
    elseif not isUsable then -- if the level is small
      mr, mg, mb, ir, ig, ib = .5, .5, 0 -- yellow color
    elseif GrimoireDB[itemID] then -- if grimoire is known
      mr, mg, mb, ir, ig, ib = 0, .5, .5 -- green color
      itemButton:SetScript("OnClick", nil) -- disabling item buying
    else -- available for buying
      mr, mg, mb, ir, ig, ib = .5, .5, .5, 1, 1, 1 -- white color
    end
    GrimoireKeeper:ColorButton(merchantButton, itemButton, mr, mg, mb, ir, ig, ib)
  end
end

function GrimoireKeeper:ColorButton(merchantButton, itemButton, mr, mg, mb, ir, ig, ib)
  if not (ir or ig or ib) then ir, ig, ib = mr, mg, mb end
  SetItemButtonNameFrameVertexColor(merchantButton, mr, mg, mb)
  SetItemButtonSlotVertexColor(merchantButton, mr, mg, mb)
  SetItemButtonTextureVertexColor(itemButton, ir, ig, ib)
  SetItemButtonNormalTextureVertexColor(itemButton, ir, ig, ib)
end
