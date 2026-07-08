-- lib/bookshelf_fonts.lua
-- Single resolver for the fonts bookshelf renders its own UI in. In "follow"
-- mode it delegates to KOReader's named faces (byte-identical to stock); when
-- a Bookshelf UI font is chosen it returns that font's face.
--
-- IMPORTANT: KOReader's Font:getFace only resolves a font that lives in
-- ./fonts (KOReader's bundle) or a *scanned* external dir (e.g. /mnt/us/fonts).
-- It cannot load an arbitrary plugin-folder path. So the stored UI font is a
-- *resolvable* font_face -- a bare filename (for our bundled fonts, which
-- ensureInstalled copies into the scanned dir) or whatever path the font
-- picker returns from KOReader's FontList. Icon ("symbols") and mono faces
-- always pass through unchanged.

local Font     = require("ui/font")

local M = {}

-- Faces that must never be remapped (icon glyphs, monospace).
local PASSTHROUGH = { symbols = true, scfont = true, infont = true, smallinfont = true, hpkfont = true }
-- Text faces whose default weight is bold (KOReader maps these to NotoSans-Bold).
local BOLD_FACES = { tfont = true, smalltfont = true, x_smalltfont = true, smallinfofontbold = true }



-- getFace(face_name, size, opts) -> face, bold
--   opts.bold: whether the caller wanted bold for this text.
-- Returns the face AND the bold flag the widget should use (false when a real
-- bold file is returned, so the widget doesn't faux-bold on top). Always falls
-- back to the native named face if a chosen font can't be resolved -- so a
-- missing/unresolvable font degrades to "follow", never a nil-face crash.
function M:getFace(face_name, size, opts)
    opts = opts or {}
    if PASSTHROUGH[face_name] then
        return Font:getFace(face_name, size), opts.bold
    end
    --local ui = M.getUIFontFace()
    if not ui then
        if opts.italic then
            -- Derive italic sibling from the native face's realname so follow
            -- mode uses e.g. NotoSans-Italic rather than hardcoding it.
            local reg = Font:getFace(face_name, size)
            if reg and reg.realname then
                local sib = italic_sibling(reg.realname)
                if sib then
                    local itf = Font:getFace(sib, size)
                    if itf then return itf, false end
                end
            end
        end
        return Font:getFace(face_name, size), opts.bold       -- follow: identical to stock
    end
    local want_bold = opts.bold or BOLD_FACES[face_name] or false
    if want_bold then
        local sib = bold_sibling(ui)
        if sib then
            local bf = Font:getFace(sib, size)
            if bf then return bf, false end                   -- real bold file, no faux bold
        end
        local rf = Font:getFace(ui, size)
        if rf then return rf, true end                        -- no bold file: faux-bold the regular
    elseif opts.italic then
        local sib = italic_sibling(ui)
        if sib then
            local itf = Font:getFace(sib, size)
            if itf then return itf, false end
        end
        local rf = Font:getFace(ui, size)
        if rf then return rf, false end                       -- no italic variant: use regular
    else
        local rf = Font:getFace(ui, size)
        if rf then return rf, false end
    end
    return Font:getFace(face_name, size), opts.bold           -- unresolvable -> native (no crash)
end

return M
