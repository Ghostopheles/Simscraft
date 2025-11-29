local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

---@class SoundFile
---@field Path string
---@field Duration number

---@param fileName string
---@return string
local function MakePath(fileName)
    return format("Interface/AddOns/%s/Assets/%s.mp3", addonName, fileName);
end

---@param fileName string
---@param duration number
---@return SoundFile
local function MakeSoundFile(fileName, duration)
    return {
        Path = MakePath(fileName),
        Duration = duration
    };
end

local SILENT_SOUND_FILE = MakeSoundFile("Silence", 30);

local SOUND_FILES = {};

for fileName, duration in pairs(internal.SOUND_FILES) do
    tinsert(SOUND_FILES, MakeSoundFile(fileName, duration))
end

local LAST_SOUND_INDEX;

local function SelectRandomSoundFile()
    local idx;
    repeat
        idx = random(1, #SOUND_FILES);
    until idx ~= LAST_SOUND_INDEX;

    LAST_SOUND_INDEX = idx;
    return SOUND_FILES[idx];
end

local CURRENT_SOUND_HANDLE;

local function IsPlaying()
    if not CURRENT_SOUND_HANDLE then
        return false;
    end

    return C_Sound.IsPlaying(CURRENT_SOUND_HANDLE);
end

local StopSong;
local OnSongEnd;

---@param soundFile SoundFile
local function PlaySong(soundFile)
    if IsPlaying() then
        StopSong();
    end

    local willPlay, soundHandle = PlaySoundFile(soundFile.Path, "Music");
    if not willPlay then
        internal.Print("Unable to play sound file: '" .. soundFile.Path .. "'");
        return;
    end

    CURRENT_SOUND_HANDLE = soundHandle;
    C_Timer.After(soundFile.Duration, OnSongEnd);

    PlayMusic(SILENT_SOUND_FILE.Path);
end

local function PlayRandomSong()
    local soundFile = SelectRandomSoundFile();
    PlaySong(soundFile);
end

---@param fadeTime number?
function StopSong(fadeTime)
    if not IsPlaying() then
        return;
    end

    StopSound(CURRENT_SOUND_HANDLE, fadeTime or 1.5);
    StopMusic();
end

function OnSongEnd()
    if C_HouseEditor.IsHouseEditorActive() then
        PlayRandomSong();
    end
end

---@param newMode number
local function OnHouseEditorModeChanged(newMode)
    if newMode == Enum.HouseEditorMode.None then
        StopSong();
    else
        if not internal.Settings.GetSetting(internal.Setting.PlayHouseEditorMusic) then
            return;
        end

        if IsPlaying() then
            return;
        end

        PlayRandomSong();
    end
end

local Events = internal.Events;
internal.RegisterCallback(Events.HouseEditorModeChanged, OnHouseEditorModeChanged);