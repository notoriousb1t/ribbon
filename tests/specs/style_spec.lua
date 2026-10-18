local H = require("tests.helpers.addon")

-- Header bytes of a TGA file: width, height, bits per pixel, descriptor.
local function tgaInfo(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local header = f:read(18)
  f:close()
  if not header or #header < 18 then return nil end
  local b = { header:byte(1, 18) }
  return { type = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17], descriptor = b[18] }
end

describe("Compass style", function()
  local S = H.pure({ "compass/Style.lua" }).compassStyle

  describe("palette", function()
    it("has every colour as four channels between 0 and 1", function()
      for name, color in pairs(S.colors) do
        expect(#color).toBe(4)
        for i = 1, 4 do
          expect(color[i] >= 0 and color[i] <= 1).toBe(true)
        end
      end
    end)

    it("uses the logo's teal for the band and gold for the trim", function()
      -- #1f7a99 and #e9b949
      expect(S.colors.band[1]).toBeCloseTo(0x1f / 255, 2)
      expect(S.colors.band[2]).toBeCloseTo(0x7a / 255, 2)
      expect(S.colors.band[3]).toBeCloseTo(0x99 / 255, 2)
      expect(S.colors.gold[1]).toBeCloseTo(0xe9 / 255, 2)
      expect(S.colors.gold[2]).toBeCloseTo(0xb9 / 255, 2)
      expect(S.colors.gold[3]).toBeCloseTo(0x49 / 255, 2)
    end)
  end)

  describe("textures", function()
    it("point into the Ribbon addon's textures folder", function()
      for _, path in pairs(S.textures) do
        expect(path:find("Interface\\AddOns\\Ribbon\\textures\\", 1, true)).toBe(1)
      end
    end)

    it("name files that exist under src/textures", function()
      for _, name in ipairs(S.textureFiles) do
        expect(tgaInfo("src/textures/" .. name .. ".tga")).toBeTruthy()
      end
    end)

    it("match the file names exactly", function()
      expect(S.textures.capLeft).toBe("Interface\\AddOns\\Ribbon\\textures\\ribbon-cap-left")
      expect(S.textures.capRight).toBe("Interface\\AddOns\\Ribbon\\textures\\ribbon-cap-right")
      expect(S.textures.dial).toBe("Interface\\AddOns\\Ribbon\\textures\\compass-dial")
      expect(S.textures.needle).toBe("Interface\\AddOns\\Ribbon\\textures\\compass-needle")
    end)

    it("are 32-bit uncompressed TGAs with power-of-two sizes and alpha", function()
      for _, name in ipairs(S.textureFiles) do
        local info = tgaInfo("src/textures/" .. name .. ".tga")
        expect(info.type).toBe(2)
        expect(info.bits).toBe(32)
        expect(info.descriptor).toBe(0x28)
        expect(info.width == 32 or info.width == 64).toBe(true)
        expect(info.width).toBe(info.height)
      end
    end)

    it("carry the file size their header promises", function()
      for _, name in ipairs(S.textureFiles) do
        local path = "src/textures/" .. name .. ".tga"
        local info = tgaInfo(path)
        local f = io.open(path, "rb")
        local size = f:seek("end")
        f:close()
        expect(size).toBe(18 + info.width * info.height * 4)
      end
    end)
  end)

  describe("geometry", function()
    it("keeps the caps outside the band by their edge offsets", function()
      expect(S.cap.leftEdge).toBeGreaterThan(0)
      expect(S.cap.rightEdge).toBeGreaterThan(0)
      expect(S.cap.leftEdge + S.cap.rightEdge).toBeLessThan(S.cap.width * 2)
    end)

    it("makes the cap taller than the 28 px band so the tails drop below it", function()
      expect(S.cap.height).toBeGreaterThan(28)
    end)
  end)
end)
