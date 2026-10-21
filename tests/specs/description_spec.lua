local H = require("tests.helpers.addon")

local YD_PER_Y = 11.5834

describe("Descriptions", function()
  describe("registry", function()
    local ctx = H.use({ boot = true })

    it("normalizes a string, splitting lines and trimming", function()
      expect(ctx.ns.NormalizeDescription("  one \n\ntwo\r\n  ")).toEqual({ "one", "two" })
    end)

    it("normalizes a list of strings and ignores other values", function()
      expect(ctx.ns.NormalizeDescription({ "a", 5, "b", {} })).toEqual({ "a", "b" })
    end)

    it("is empty for anything else", function()
      expect(ctx.ns.NormalizeDescription(nil)).toEqual({})
      expect(ctx.ns.NormalizeDescription(42)).toEqual({})
      expect(ctx.ns.NormalizeDescription("")).toEqual({})
    end)

    it("stores the description on a new waypoint as a list", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 50, { title = "T", description = "Do the thing" })
      expect(ctx.ns:GetWaypoint(uid).description).toEqual({ "Do the thing" })
    end)

    it("defaults to an empty list", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 50)
      expect(ctx.ns:GetWaypoint(uid).description).toEqual({})
    end)
  end)

  describe("layout", function()
    local L = H.pure({ "core/Geometry.lua", "compass/Layout.lua" }).compassLayout

    it("keeps short text as it is", function()
      expect(L.shorten("short", 70)).toBe("short")
    end)

    it("cuts long text with an ellipsis within the limit", function()
      local text = string.rep("a", 100)
      local out = L.shorten(text, 20)
      expect(#out).toBeLessThan(21)
      expect(out:sub(-3)).toBe("...")
    end)

    it("does not leave half of a multi-byte character", function()
      -- "e acute" is two bytes (0xC3 0xA9); cutting between them would break the string.
      local text = string.rep("a", 17) .. "\195\169\195\169\195\169"
      local out = L.shorten(text, 20)
      expect(out:find("\195%.%.%.$")).toBeNil()
      expect(out:sub(-3)).toBe("...")
    end)

    it("returns at most two description lines, each shortened", function()
      local wp = { description = { "one", "two", "three" } }
      expect(L.details(wp)).toEqual({ "one", "two" })
      local long = { description = { string.rep("x", 200) } }
      expect(#L.details(long)[1]).toBeLessThan(71)
    end)

    it("is empty without a description", function()
      expect(L.details({})).toEqual({})
      expect(L.details(nil)).toEqual({})
    end)
  end)

  describe("compass caption", function()
    local ctx = H.use({ boot = true })
    local parts

    local function frameTick() ctx.world:update(0.04) end
    local function lastText(fs) local c = fs.SetText.calls return c[#c][1] end

    beforeEach(function()
      ctx.world:placePlayer(1453, 61.99, 70.58, 0)
      parts = ctx.ns.compass.parts
    end)

    it("shows the description under the headline", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "Break Sharptusk!", description = "Sharptusk Thornmantle slain: 0/1" })
      frameTick()
      expect(lastText(parts.targetText)).toBe("Break Sharptusk!")
      expect(lastText(parts.detailText)).toBe("Sharptusk Thornmantle slain: 0/1")
    end)

    it("shows two lines for two description lines", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T", description = { "first", "second" } })
      frameTick()
      expect(lastText(parts.detailText)).toBe("first\nsecond")
    end)

    it("has an empty detail line when there is no description", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "Plain" })
      frameTick()
      expect(lastText(parts.detailText)).toBe("")
    end)

    it("shows the plate while there is a caption and hides it without one", function()
      local uid = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T" })
      frameTick()
      expect(parts.captionPlate:IsShown()).toBe(true)
      ctx.ns:RemoveWaypoint(uid)
      frameTick()
      expect(parts.captionPlate:IsShown()).toBe(false)
    end)

    it("sizes the plate to at least the minimum width", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T" })
      frameTick()
      local calls = parts.captionPlate.SetSize.calls
      expect(calls[#calls][1]).toBeGreaterThan(ctx.ns.compassStyle.caption.minWidth - 1)
    end)

    it("sizes the plate from the text it measures", function()
      -- the fake client has no real font metrics, so give the strings a measured width and height
      parts.targetText.GetStringWidth = function() return 240 end
      parts.targetText.GetStringHeight = function() return 14 end
      parts.detailText.GetStringWidth = function() return 180 end
      parts.detailText.GetStringHeight = function() return 12 end
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T", description = "d" })
      frameTick()
      local calls = parts.captionPlate.SetSize.calls
      local style = ctx.ns.compassStyle.caption
      expect(calls[#calls][1]).toBe(240 + style.iconSize + style.iconGap + style.padX * 2)
      expect(calls[#calls][2]).toBe(14 + style.padY * 2 + style.lineGap + 12)
    end)

    it("wraps a long line at the guide panel's line length", function()
      parts.targetText.GetStringWidth = function() return 500 end
      parts.targetText.GetStringHeight = function() return 28 end
      parts.detailText.GetStringWidth = function() return 100 end
      parts.detailText.GetStringHeight = function() return 12 end
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T", description = "d" })
      frameTick()
      local style = ctx.ns.compassStyle.caption
      local calls = parts.captionPlate.SetSize.calls
      expect(calls[#calls][1]).toBe(style.maxWidth + style.iconSize + style.iconGap + style.padX * 2)
      expect(parts.targetText.SetWidth).toHaveBeenCalledWith(style.maxWidth + 2)
    end)

    it("shows the step's symbol at the left of the plate, ringed while it is the tracked waypoint", function()
      local uid = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T", icon = "accept" })
      frameTick()
      local style = ctx.ns.compassStyle
      expect(parts.captionIcon:IsShown()).toBe(true)
      expect(parts.captionIcon.questRing:IsShown()).toBe(false)
      ctx.ns:SetFocus(uid)
      frameTick()
      expect(parts.captionIcon.questRing:IsShown()).toBe(true)
      expect(parts.captionIcon.glyphTex.SetTexture).toHaveBeenCalledWith(style.textures.questExclaim)
    end)

    it("shows the distance above the bar over each marker", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T" })
      frameTick()
      local m = parts.markers[1]
      expect(m.dist:IsShown()).toBe(true)
      expect(lastText(m.dist)).toContain("yd")
      expect(m.dist.SetPoint.calls[#m.dist.SetPoint.calls][2]).toBe(parts.frame)
      expect(m.dist.SetPoint.calls[#m.dist.SetPoint.calls][3]).toBe("TOP")
    end)

    it("puts the card and the yards below the ribbon in the upper half of the screen, above it in the lower half", function()
      UIParent.GetHeight = function() return 1000 end
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T" })
      parts.frame.GetCenter = function() return 500, 900 end
      frameTick()
      local m = parts.markers[1]
      local last = m.dist.SetPoint.calls[#m.dist.SetPoint.calls]
      expect(last[1]).toBe("TOP")
      expect(last[3]).toBe("BOTTOM")
      local plate = parts.captionPlate.SetPoint.calls[#parts.captionPlate.SetPoint.calls]
      expect(plate[1]).toBe("TOP")
      expect(plate[3]).toBe("BOTTOM")
      parts.frame.GetCenter = function() return 500, 100 end
      frameTick()
      last = m.dist.SetPoint.calls[#m.dist.SetPoint.calls]
      expect(last[1]).toBe("BOTTOM")
      plate = parts.captionPlate.SetPoint.calls[#parts.captionPlate.SetPoint.calls]
      expect(plate[1]).toBe("BOTTOM")
    end)

    it("shows the description in the tooltip too", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "T", description = "Do the thing" })
      frameTick()
      parts.markers[1]:Trigger("OnEnter")
      expect(GameTooltip.AddLine).toHaveBeenCalledWith("Do the thing", 1, 1, 1, true)
    end)

    it("uses the game's own fonts, shadowed, with no outline of its own", function()
      expect(parts.targetText.SetFont).never.toHaveBeenCalled()
      expect(parts.detailText.SetFont).never.toHaveBeenCalled()
    end)
  end)

  describe("quest description", function()
    local T = H.pure({ "integrations/QuestTranslate.lua" }).questTranslate

    it("lists the unfinished objectives", function()
      expect(T.description({
        { text = "Sharptusk Thornmantle slain: 0/1", finished = false, type = "monster" },
        { text = "Boar slain: 8/8", finished = true, type = "monster" },
      })).toEqual({ "Sharptusk Thornmantle slain: 0/1" })
    end)

    it("uses the hand-in text when every objective is finished", function()
      expect(T.description({
        { text = "Bring the Request to Furen Longbeard in Stormwind.", finished = true, type = "log" },
      })).toEqual({ "Bring the Request to Furen Longbeard in Stormwind." })
    end)

    it("says ready to turn in when finished objectives have no hand-in text", function()
      expect(T.description({ { text = "Boar slain: 8/8", finished = true, type = "monster" } }))
        .toEqual({ "Ready to turn in" })
    end)

    it("is empty without objectives", function()
      expect(T.description({})).toEqual({})
      expect(T.description(nil)).toEqual({})
    end)
  end)

  describe("RXP description", function()
    local T = H.pure({ "integrations/RXPTranslate.lua" }).rxpTranslate

    it("uses the step text without markup", function()
      expect(T.description({ title = "Furen", text = "|cffffd200Turn in|r RXP_FRIENDLY_the Order|r |T123:0|t" }))
        .toEqual({ "Turn in the Order" })
    end)

    it("is empty when the text repeats the title or is missing", function()
      expect(T.description({ title = "Furen", text = "Furen" })).toEqual({})
      expect(T.description({ title = "Furen" })).toEqual({})
    end)
  end)
end)
