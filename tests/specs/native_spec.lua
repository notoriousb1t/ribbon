local H = require("tests.helpers.addon")

-- The game's own frame template and search box, simulated: the fake client makes any frame, so these specs hand out
-- frames that carry the parts the real templates have.
describe("The game's frame template and search box", function()
  local ctx = H.use({ boot = true })
  local real
  local made

  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
    real = _G.CreateFrame
    made = {}
    _G.CreateFrame = function(kind, name, parent, template)
      local o = real(kind, name, parent, template)
      if template == "ButtonFrameTemplate" then
        o.Inset = real("Frame", nil, o)
        o.TopTileStreaks = real("Frame", nil, o)
        o.CloseButton = real("Button", nil, o)
        made.frame = o
      elseif template == "SearchBoxTemplate" then
        o.Instructions = real("FontString", nil, o)
        made.search = o
      end
      return o
    end
    _G.ButtonFrameTemplate_HidePortrait = function() end
    _G.ButtonFrameTemplate_HideButtonBar = function(f) made.buttonBarHidden = f end
  end)
  afterEach(function()
    _G.CreateFrame = real
    _G.ButtonFrameTemplate_HidePortrait = nil
    _G.ButtonFrameTemplate_HideButtonBar = nil
  end)

  local function open()
    ctx.ns.guideBrowser.toggleDock()
    return ctx.ns.guideBrowser.dock()
  end

  describe("the frame", function()
    it("drops the button bar and the band under the title, so the content has the room", function()
      local d = open()
      expect(made.buttonBarHidden).toBe(d)
      expect(d.TopTileStreaks:IsShown()).toBe(false)
    end)

    it("puts the inset right under the title bar and down to the frame's bottom", function()
      local d = open()
      expect(d.Inset.SetPoint).toHaveBeenCalledWith("TOPLEFT", d, "TOPLEFT", 6, -26)
      expect(d.Inset.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", d, "BOTTOMRIGHT", -6, 6)
    end)

    it("hangs the search box and the lists from the inset", function()
      local d = open()
      expect(d.search.SetPoint).toHaveBeenCalledWith("TOPLEFT", d.Inset, "TOPLEFT", 14, -8)
      expect(d.leftScroll.SetPoint).toHaveBeenCalledWith("TOPLEFT", d.Inset, "TOPLEFT", 8, -(34 + 26))
    end)

    it("has no X on its title bar", function()
      local d = open()
      expect(d.CloseButton:IsShown()).toBe(false)
      expect(d.close).toBe(d.CloseButton)
    end)

    it("works without the button bar helper (an older template)", function()
      _G.ButtonFrameTemplate_HideButtonBar = nil
      local d = open()
      expect(d.native).toBe(true)
      expect(made.buttonBarHidden).toBeNil()
    end)
  end)

  describe("the search box", function()
    it("uses the template's own placeholder and adds nothing over it", function()
      local d = open()
      expect(d.search.templated).toBe(true)
      expect(d.search.Instructions.SetText).toHaveBeenCalledWith("Search chapters and steps")
      expect(d.search.hint).toBeNil()
      expect(d.search.clear).toBeNil()
    end)

    it("listens alongside the template's scripts instead of replacing them", function()
      local d = open()
      expect(d.search.HookScript).toHaveBeenCalledWith("OnTextChanged", d.search.HookScript.calls[1][2])
      expect(d.search:GetScript("OnTextChanged")).toBeNil()        -- nothing set over the template's own
    end)

    it("still narrows the lists as the player types", function()
      local d = open()
      local hooked = d.search.HookScript.calls[1][2]
      d.search:SetText("zzzz")
      hooked(d.search)
      expect(d.empty:IsShown()).toBe(true)
      d.search:SetText("")
      hooked(d.search)
      expect(d.empty:IsShown()).toBe(false)
    end)

    it("is cleared and refilled from code without touching the placeholder", function()
      local d = open()
      ctx.ns.guideBrowser.setQuery("abc")
      expect(d.search:GetText()).toBe("abc")
    end)
  end)
end)
