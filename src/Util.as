// c 2024-03-06
// m 2024-03-11

SQLite::Database@ timeDB = SQLite::Database(":memory:");

// courtesy of "Play Map" plugin - https://github.com/XertroV/tm-play-map
void EditMap() {
    if (!hasEditPermission || loading || gbx.path.Length == 0 || gbxMap is null)
        return;

    loading = true;

    trace("loading map \"" + StripFormatCodes(gbxMap.MapName) + "\" for editing");

    ReturnToMenu();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    App.ManiaTitleControlScriptAPI.EditMap(gbx.path, "", "");

    const uint64 waitToEditAgain = 5000;
    const uint64 now = Time::Now;

    while (Time::Now - now < waitToEditAgain)
        yield();

    loading = false;
}

// not working - can't load from cache folder, replays in user folder aren't cached?
// void EditReplay() {
//     if (loading || gbx.path.Length == 0 || gbxGhost is null)
//         return;

//     loading = true;

//     trace("loading replay \"" + gbxGhost.Validate_ChallengeUid.GetName() + " - " + gbxGhost.GhostNickname + "\" for editing");

//     ReturnToMenu();

//     CTrackMania@ App = cast<CTrackMania@>(GetApp());

//     MwFastBuffer<wstring> replayList;
//     replayList.Add(gbx.path);

//     App.ManiaTitleControlScriptAPI.EditReplay(replayList);

//     const uint64 waitToEditAgain = 5000;
//     const uint64 now = Time::Now;

//     while (Time::Now - now < waitToEditAgain)
//         yield();

//     loading = false;
// }

string ForSlash(const string &in path) {
    return path.Replace("\\", "/");
}

string GetSizeMB(uint size, uint precision = 1) {
    return Text::Format("%." + precision + "f", float(size) / 1048576.0f) + " MB";
}

void HoverTooltip(const string &in msg) {
    if (!UI::IsItemHovered())
        return;

    UI::BeginTooltip();
        UI::Text(msg);
    UI::EndTooltip();
}

string InsertSeparators(int num) {
    int abs = Math::Abs(num);
    if (abs < 1000)
        return tostring(num);

    string str = tostring(abs);

    string result;

    for (int i = 0; i < str.Length; i++) {
        if (i > 0 && (str.Length - i) % 3 == 0)
            result += S_Separator;

        result += str.SubStr(i, 1);
    }

    if (num < 0)
        result = "-" + result;

    return result;
}

// courtesy of MisfitMaid
int64 IsoToUnix(const string &in inTime) {
    SQLite::Statement@ s = timeDB.Prepare("SELECT unixepoch(?) as x");
    s.Bind(1, inTime);
    s.Execute();
    s.NextRow();
    s.NextRow();
    return s.GetColumnInt64("x");
}

// courtesy of "4GB Cache" - https://github.com/XertroV/tm-4gb-cache
uint MeasureFidSizes(CSystemFidsFolder@ folder) {
    uint total = 0;

    for (uint i = 0; i < folder.Trees.Length; i++) {
        CSystemFidsFolder@ fid = folder.Trees[i];
        total += fid.ByteSize;
    }

    for (uint i = 0; i < folder.Leaves.Length; i++) {
        CSystemFidFile@ fid = folder.Leaves[i];
        total += fid.ByteSize;
    }

    return total;
}

// courtesy of "Play Map" plugin - https://github.com/XertroV/tm-play-map
void PlayMap() {
    if (!hasPlayPermission || loading || gbx.path.Length == 0 || gbxMap is null || gbxMap.TMObjective_AuthorTime == uint(-1))
        return;

    loading = true;

    trace("loading map \"" + StripFormatCodes(gbxMap.MapName) + "\" for playing");

    ReturnToMenu();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    App.ManiaTitleControlScriptAPI.PlayMap(gbx.path, "TrackMania/TM_PlayMap_Local", "");

    const uint64 waitToPlayAgain = 5000;
    const uint64 now = Time::Now;

    while (Time::Now - now < waitToPlayAgain)
        yield();

    loading = false;
}

// courtesy of "4GB Cache" - https://github.com/XertroV/tm-4gb-cache
void ReadCacheUsage() {
    cacheUsage = 0;

    try {
        CSystemFidsFolder@ cache = Fids::GetProgramDataFolder("Cache");
        cacheUsage = MeasureFidSizes(cache);
    } catch {
        error("error getting cache size: " + getExceptionInfo());
    }
}

void ReadChecksumFile() {
    if (reading)
        return;

    reading = true;

    trace("reading checksum file...");

    @archive = null;
    @archiveFile = null;
    @audio = null;
    @audioLoaded = null;
    @deleteQueued = null;
    @gbx = null;
    @gbxGhost = null;
    @gbxMap = null;
    @image = null;
    text = "";
    packs.RemoveRange(0, packs.Length);

    if (IO::FileExists(checksumFile)) {
        IO::File file(checksumFile, IO::FileMode::Read);
        string xml = file.ReadToEnd();
        file.Close();

        XML::Document doc(xml);
        XML::Node cache = doc.Root().FirstChild();
        XML::Node node = cache.FirstChild();
        packs.InsertLast(Pack(node));

        int i = 1;

        while (true) {
            node = node.NextSibling();
            Pack pack(node);
            if (pack.checksum.Length == 0)
                break;
            packs.InsertLast(pack);

            if (i++ % 10 == 0)
                yield();
        }
    } else {
        warn("checksum file not found");
        reading = false;
        return;
    }

    trace("reading checksum file done! (" + packs.Length + " packs)");

    dirty = true;
    reading = false;

    startnew(ReadCacheUsage);
}

// courtesy of "BetterTOTD" plugin - https://github.com/XertroV/tm-better-totd
void ReturnToMenu() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    if (App.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed)
        App.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);

    App.BackToMainMenu();

    while (!App.ManiaTitleControlScriptAPI.IsReady)
        yield();
}
