// courtesy of "Play Map" plugin - https://github.com/XertroV/tm-play-map
void EditMap() {
    if (false
        or !hasEditPermission
        or loading
        or gbx.path.Length == 0
        or gbxMap is null
    ) {
        return;
    }

    loading = true;

    trace("loading map \"" + Text::StripFormatCodes(gbxMap.MapName) + "\" for editing");

    ReturnToMenu();

    auto App = cast<CTrackMania>(GetApp());

    App.ManiaTitleControlScriptAPI.EditMap(gbx.path, "", "");

    const uint64 waitToEditAgain = 5000;
    const uint64 now = Time::Now;

    while (Time::Now - now < waitToEditAgain) {
        yield();
    }

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

string ForSlash(const string&in path) {
    return path.Replace("\\", "/");
}

string GetSizeDynamic(const uint size, const uint precision = 1) {
    if (size >= 1073741824) {
        return Text::Format("%." + precision + "f", float(size) / 1073741824.f) + " GiB";
    }
    if (size >= 1048576) {
        return Text::Format("%." + precision + "f", float(size) / 1048576.f) + " MiB";
    }
    if (size >= 1024) {
        return Text::Format("%." + precision + "f", float(size) / 1024.f) + " KiB";
    }
    return tostring(size) + " B";
}

void HoverTooltip(const string&in msg) {
    if (!UI::IsItemHovered()) {
        return;
    }

    UI::BeginTooltip();
    UI::Text(msg);
    UI::EndTooltip();
}

string InsertSeparators(const int num) {
    int abs = Math::Abs(num);
    if (abs < 1000) {
        return tostring(num);
    }

    string str = tostring(abs);

    string result;

    for (int i = 0; i < str.Length; i++) {
        if (true
            and i > 0
            and (str.Length - i) % 3 == 0
        ) {
            result += S_Separator;
        }

        result += str.SubStr(i, 1);
    }

    if (num < 0) {
        result = "-" + result;
    }

    return result;
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
    if (false
        or !hasPlayPermission
        or loading
        or gbx.path.Length == 0
        or gbxMap is null
        or gbxMap.TMObjective_AuthorTime == uint(-1)
    ) {
        return;
    }

    loading = true;

    trace("loading map \"" + Text::StripFormatCodes(gbxMap.MapName) + "\" for playing");

    ReturnToMenu();

    auto App = cast<CTrackMania>(GetApp());

    string mode = "";
    if (gbxMap.MapType.EndsWith("Race")) {
        mode = "TrackMania\\TM_PlayMap_Local";
    } else if (gbxMap.MapType.EndsWith("Stunt")) {
        mode = "Trackmania\\TM_StuntSolo_Local";
    } else if (gbxMap.MapType.EndsWith("Platform")) {
        mode = "Trackmania\\TM_Platform_Local";
    } else if (gbxMap.MapType.EndsWith("Royal")) {
        mode = "Trackmania\\TM_RoyalTimeAttack_Local";
    } else if (gbxMap.MapType == "") {
        print('no mode, defaulting to race');
        mode = "TrackMania\\TM_PlayMap_Local";
    } else {
        print('unknown mode: ' + gbxMap.MapType);
    }

    App.ManiaTitleControlScriptAPI.PlayMap(gbx.path, mode, "");

    const uint64 waitToPlayAgain = 5000;
    const uint64 now = Time::Now;

    while (Time::Now - now < waitToPlayAgain) {
        yield();
    }

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
    if (reading) {
        return;
    }

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
            if (pack.checksum.Length == 0) {
                break;
            }
            packs.InsertLast(pack);

            if (i++ % 10 == 0) {
                yield();
            }
        }
    } else {
        warn("checksum file not found");
        reading = false;
        return;
    }

    trace("reading checksum file done! (" + packs.Length + " packs)");

    dirty = true;
    reading = false;

    startnew(ScanMapNames);
    startnew(ReadCacheUsage);
}

// courtesy of "BetterTOTD" plugin - https://github.com/XertroV/tm-better-totd
void ReturnToMenu() {
    auto App = cast<CTrackMania>(GetApp());

    if (App.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed) {
        App.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(
            CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit
        );
    }

    App.BackToMainMenu();

    while (!App.ManiaTitleControlScriptAPI.IsReady) {
        yield();
    }
}

void ScanMapNames() {
    uint64 now, lastYield = Time::Now;
    uint cacheMaps = 0;
    for (uint i = 0; i < packs.Length; i++) {
        if (packs[i].type == FileType::Map) {
            Pack@ pack = packs[i];
            CSystemFidFile@ fid;
            if (pack.root == "shared") {
                @fid = Fids::GetProgramData(pack.file);
            } else if (pack.root == "user") {
                @fid = Fids::GetUser(pack.file);
            } else if (pack.root == "data") {
                @fid = Fids::GetGame("GameData/" + pack.file);
            }

            if (fid !is null) {
                @gbxMap = cast<CGameCtnChallenge>(Fids::Preload(fid));
                pack.chosenName = gbxMap.MapName;
                cacheMaps++;
            } else {
                warn("null fid: " + pack.path);
            }

            now = Time::Now;
            if (now - lastYield > maxFrameTime) {
                lastYield = now;
                yield();
            }
        }
    }

    trace("checking map names done! (" + cacheMaps + " cached maps)");
}
