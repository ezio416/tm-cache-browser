// c 2024-03-06
// m 2024-05-28

void Main() {
    developer = Meta::IsDeveloperMode();
    hasEditPermission = Permissions::OpenAdvancedMapEditor();
    hasPlayPermission = Permissions::PlayLocalMap();

    programDataPath = ForSlash(Fids::GetProgramDataFolder("").FullDirName);
    cachePath = programDataPath + "Cache/";
    checksumFile = programDataPath + "checksum.txt";

    if (S_AutoRead)
        startnew(ReadChecksumFile);
}

void RenderMenu() {
    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Render() {
    if (
        !S_Enabled
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || (S_HideWithOP && !UI::IsOverlayShown())
    )
        return;

    UI::Begin(title, S_Enabled, UI::WindowFlags::None);
        UI::BeginDisabled(reading);
        if (UI::Button(Icons::File + " Read Checksum File (" + packsSorted.Length + " Packs)"))
            startnew(ReadChecksumFile);
        UI::EndDisabled();

        UI::SameLine();
        if (UI::Button(Icons::Refresh + " Refresh Cache Usage (" + GetSizeMB(cacheUsage) + ")"))
            startnew(ReadCacheUsage);

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Cache Folder"))
            OpenExplorerPath(cachePath);

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Trackmania User Folder"))
            OpenExplorerPath(IO::FromUserGameFolder(""));

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Trackmania Game Folder"))
            OpenExplorerPath(IO::FromAppFolder(""));

        search = UI::InputText("search names", search, false);

        if (search.Length > 0) {
            UI::SameLine();
            if (UI::Button(Icons::Times + " Clear Search"))
                search = "";

            UI::SameLine();
            UI::Text(searchResults + " results");
        }

        Table_Main();

    UI::End();

    RenderArchivePreview();
    RenderAudioPreview();
    RenderGbxPreview();
    RenderImagePreview();
    RenderTextPreview();
    RenderDeleteConfirmation();
    RenderDebug();
}

void Table_Main() {
    int columns = 5;
    if (developer)
        columns++;
    if (S_AllowDelete)
        columns++;

    if (UI::BeginTable("##table-main", columns, UI::TableFlags::RowBg | UI::TableFlags::ScrollY | UI::TableFlags::Sortable)) {
        UI::PushStyleColor(UI::Col::TableRowBgAlt, rowBgAltColor);

        UI::TableSetupScrollFreeze(0, 1);
        UI::TableSetupColumn("type", UI::TableColumnFlags::WidthFixed, scale * 65.0f);
        UI::TableSetupColumn("size", UI::TableColumnFlags::WidthFixed, scale * 65.0f);
        UI::TableSetupColumn("last use (UTC)", UI::TableColumnFlags::WidthFixed, scale * 120.0f);
        UI::TableSetupColumn("path", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort, scale * 100.0f);
        if (developer)
            UI::TableSetupColumn("nod", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort, scale * 110.0f);
        if (S_AllowDelete)
            UI::TableSetupColumn("delete", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort, scale * 75.0f);
        UI::TableSetupColumn("name");
        UI::TableHeadersRow();

        UI::TableSortSpecs@ tableSpecs = UI::TableGetSortSpecs();

        if (tableSpecs !is null && (tableSpecs.Dirty || dirty)) {
            UI::TableColumnSortSpecs[]@ colSpecs = tableSpecs.Specs;

            if (colSpecs !is null && colSpecs.Length > 0) {
                bool ascending = colSpecs[0].SortDirection == UI::SortDirection::Ascending;

                if (colSpecs[0].ColumnIndex == 0)
                    sortMethod = ascending ? SortMethod::TypeAlpha : SortMethod::TypeAlphaRev;
                else if (colSpecs[0].ColumnIndex == 1)
                    sortMethod = ascending ? SortMethod::SmallestFirst : SortMethod::LargestFirst;
                else if (colSpecs[0].ColumnIndex == 2)
                    sortMethod = ascending ? SortMethod::OldestFirst : SortMethod::NewestFirst;
                else if (colSpecs[0].ColumnIndex == columns - 1)
                    sortMethod = ascending ? SortMethod::NameAlpha : SortMethod::NameAlphaRev;

                startnew(SortPacks);
            }

            tableSpecs.Dirty = false;
            dirty = false;
        }

        Pack@[] packsFiltered;

        const string searchLower = search.ToLower();

        for (uint i = 0; i < packsSorted.Length; i++) {
            Pack@ pack = packsSorted[i];

            if (searchLower.Length == 0 || pack.name.ToLower().Contains(searchLower))
                packsFiltered.InsertLast(pack);
        }

        searchResults = packsFiltered.Length;

        UI::ListClipper clipper(packsFiltered.Length);
        while (clipper.Step()) {
            for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                Pack@ pack = packsFiltered[i];

                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(pack.type == FileType::Unknown ? "\\$F00Unknown" : tostring(pack.type));

                UI::TableNextColumn();
                UI::Text(GetSizeMB(pack.size, 2));
                HoverTooltip(InsertSeparators(pack.size) + " B");

                UI::TableNextColumn();
                UI::Text(tostring(pack.lastuseIso.SubStr(0, 16)));
                HoverTooltip(tostring(pack.lastuseUnix));

                UI::TableNextColumn();
                if (pack.path.Length > 0 && UI::Selectable(Icons::Clipboard + " Copy Path##" + pack.path, false))
                    IO::SetClipboard(pack.path);
                HoverTooltip(pack.path);

                if (developer) {
                    UI::TableNextColumn();
                    if (pack.path.Length > 0 && UI::Selectable(Icons::ExternalLink + " Explore Nod##" + pack.path, false)) {
                        CSystemFidFile@ fid;

                        if (pack.root == "shared")
                            @fid = Fids::GetProgramData(pack.file);
                        else if (pack.root == "user")
                            @fid = Fids::GetUser(pack.file);
                        else if (pack.root == "data")
                            @fid = Fids::GetGame("GameData/" + pack.file);

                        if (fid !is null) {
                            CMwNod@ nod = Fids::Preload(fid);
                            if (nod !is null)
                                ExploreNod(nod);
                            else
                                warn("null nod: " + pack.path);
                        } else
                            warn("null fid: " + pack.path);
                    }
                }

                if (S_AllowDelete) {
                    UI::TableNextColumn();
                    if (pack.root == "shared" && UI::Selectable(Icons::Trash + " Delete##" + pack.path, false))
                        @deleteQueued = pack;
                }

                UI::TableNextColumn();
                switch (pack.type) {
                    case FileType::Archive:
                    case FileType::CarSkin:
                    case FileType::MapMod:
                        if (UI::Selectable(pack.name, false)) {
                            @archive = pack;

                            CSystemFidFile@ fid;

                            if (archive.root == "shared")
                                @fid = Fids::GetProgramData(archive.file);
                            else if (archive.root == "user")
                                @fid = Fids::GetUser(archive.file);
                            else if (archive.root == "data")
                                @fid = Fids::GetGame("GameData/" + archive.file);

                            if (fid !is null)
                                @archiveFile = cast<CPlugFileZip@>(Fids::Preload(fid));
                            else
                                warn("null fid: " + archive.path);
                        }
                        break;

                    case FileType::Audio:
                        if (UI::Selectable(pack.name, false)) {
                            @audio = null;
                            @audioLoaded = null;

                            try {
                                @audio = Audio::LoadSampleFromAbsolutePath(pack.path);
                            } catch {
                                warn("reading audio file failed: " + pack.path);
                            }

                            audioName = pack.name;
                            audioExtension = pack.extension.ToUpper();
                        }
                        break;

                    case FileType::Image:
                        if (UI::Selectable(pack.name, false)) {
                            @image = null;

                            IO::File file(pack.path, IO::FileMode::Read);
                            try {
                                @image = UI::LoadTexture(file.Read(file.Size()));
                            } catch {
                                warn("reading image file failed: " + pack.path);
                            }
                            file.Close();

                            imageName = pack.name;
                            imageExtension = pack.extension.ToUpper();

                            CSystemFidFile@ fid;

                            if (pack.file.StartsWith("Cache"))
                                @fid = Fids::GetProgramData(pack.file);
                            else
                                @fid = Fids::GetUser(pack.file);

                            CPlugFileImg@ img = cast<CPlugFileImg@>(Fids::Preload(fid));
                            if (img !is null)
                                imageSize = vec2(float(img.Width), float(img.Height));
                            else {
                                warn("null image from fid: " + pack.path);
                                imageSize = vec2(512.0f, 512.0f);
                            }
                        }
                        break;

                    case FileType::Map:
                    case FileType::Replay:
                        if (UI::Selectable(pack.name, false)) {
                            @gbx = pack;

                            CSystemFidFile@ fid;

                            if (gbx.root == "shared")
                                @fid = Fids::GetProgramData(gbx.file);
                            else if (gbx.root == "user")
                                @fid = Fids::GetUser(gbx.file);
                            else if (gbx.root == "data")
                                @fid = Fids::GetGame("GameData/" + gbx.file);

                            if (fid !is null) {
                                if (gbx.type == FileType::Map)
                                    @gbxMap = cast<CGameCtnChallenge@>(Fids::Preload(fid));
                                else
                                    @gbxGhost = cast<CGameCtnGhost@>(Fids::Preload(fid));
                            } else
                                warn("null fid: " + gbx.path);
                        }
                        break;

                    case FileType::Text:
                        if (UI::Selectable(pack.name, false)) {
                            text = "";

                            IO::File file(pack.path, IO::FileMode::Read);
                            try {
                                text = file.ReadToEnd();
                            } catch {
                                warn("reading text file failed: " + pack.path);
                            }
                            file.Close();

                            textName = pack.name;
                            textExtension = pack.extension.ToUpper();
                        }
                        break;

                    default:
                        UI::Text(pack.name);
                }
            }
        }

        UI::PopStyleColor();
        UI::EndTable();
    }
}

void RenderArchivePreview() {
    if (archive is null)
        return;

    archiveWindow = true;

    UI::Begin(title + " (" + archive.extension.ToUpper() + " Archive)###" + title + "-archive", archiveWindow, UI::WindowFlags::AlwaysAutoResize);
        UI::Text(archive.name);

        UI::Separator();

        if (UI::BeginTable("##table-archive", 2, UI::TableFlags::RowBg)) {
            UI::PushStyleColor(UI::Col::TableRowBgAlt, rowBgAltColor);

            UI::TableSetupColumn("var", UI::TableColumnFlags::WidthFixed, scale * 100.0f);

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("type");
            UI::TableNextColumn();
            UI::Text(tostring(archive.type));

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("size");
            UI::TableNextColumn();
            UI::Text(GetSizeMB(archive.size, 2));
            HoverTooltip(InsertSeparators(archive.size) + " B");

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("last use (UTC)");
            UI::TableNextColumn();
            UI::Text(archive.lastuseIso);
            HoverTooltip(tostring(archive.lastuseUnix));

            string rootFolder;

            if (archive.root == "shared")
                rootFolder = cachePath;
            else if (archive.root == "user")
                rootFolder = ForSlash(IO::FromUserGameFolder(""));
            else if (archive.root == "data")
                rootFolder = ForSlash(IO::FromAppFolder("GameData/"));

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("root");
            UI::TableNextColumn();
            if (UI::Selectable(archive.root + " (" + rootFolder + ")", false))
                OpenExplorerPath(rootFolder);
            HoverTooltip(Icons::ExternalLinkSquare + " Open Folder");

            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text("path");
            UI::TableNextColumn();
            if (UI::Selectable(archive.path, false))
                IO::SetClipboard(archive.path);
            HoverTooltip(Icons::Clipboard + " Copy");

            if (archiveFile !is null) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("# folders");
                UI::TableNextColumn();
                UI::Text(tostring(archiveFile.NbFolders));

                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("# files");
                UI::TableNextColumn();
                UI::Text(tostring(archiveFile.NbFiles));
            }

            UI::PopStyleColor();
            UI::EndTable();
        }

    if (archive.permaCached || (archive.root == "shared" && archive.type == FileType::MapMod)) {
        UI::Separator();

        if (archive.permaCached)
            UI::TextWrapped("\\$FF0File has been permanently cached.");
        else {
            if (UI::Button("Permanently Cache (Move to " + ForSlash(IO::FromUserGameFolder("")) + ")"))
                archive.PermaCache();
        }

        if (archive.permaCacheIssue) {
            UI::TextWrapped("\\$FA0There was a problem permanently caching the file. You should check the Openplanet log, restart your game, and try again. If the problem persists, please open a GitHub issue and include your log:");

            if (UI::Button(Icons::Github + " Issues"))
                OpenBrowserURL("https://github.com/ezio416/tm-cache-browser/issues");

            UI::SameLine();
            if (UI::Button(Icons::ExternalLinkSquare + " Open Openplanet Folder"))
                OpenExplorerPath(IO::FromDataFolder(""));
        }
    }

    UI::End();

    if (!archiveWindow) {
        @archive = null;
        @archiveFile = null;
    }
}

void RenderAudioPreview() {
    if (audio is null)
        return;

    audioWindow = true;

    if (audioLoaded is null) {
        @audioLoaded = Audio::Play(audio, 0.5f);

        if (audioLoaded !is null)
            audioLoaded.Pause();
    }

    UI::Begin(title + " (" + audioExtension + " Audio)###" + title + "-audio", audioWindow, UI::WindowFlags::AlwaysAutoResize);
        UI::Text(audioName);

        UI::Separator();

        if (audioLoaded !is null) {
            const uint position = uint(audioLoaded.GetPosition() * 1000.0);
            const uint length = uint(audioLoaded.GetLength() * 1000.0);
            const string progress = Time::Format(position) + " / " + Time::Format(length);
            UI::SliderInt("##audio-slider", position, 0, length, progress, UI::SliderFlags::NoInput);

            const float gain = audioLoaded.GetGain();
            const float newGain = UI::SliderFloat("##audio-gain", gain, 0.0f, 1.0f, "Gain: %.3f", UI::SliderFlags::NoInput);
            if (gain != newGain)
                audioLoaded.SetGain(newGain);

            if (audioLoaded.IsPaused()) {
                if (UI::Button("Play"))
                    audioLoaded.Play();
            } else {
                if (UI::Button("Pause"))
                    audioLoaded.Pause();
            }
        } else
            UI::Text(audioExtension + " audio file not supported");

    UI::End();

    if (!audioWindow) {
        @audio = null;

        if (audioLoaded !is null && !audioLoaded.IsPaused())
            audioLoaded.Pause();

        @audioLoaded = null;
    }
}

void RenderGbxPreview() {
    if (gbx is null)
        return;

    gbxWindow = true;

    UI::Begin(title + " (" + tostring(gbx.type) + " GameBox)###" + title + "-gamebox", gbxWindow, UI::WindowFlags::AlwaysAutoResize);
        UI::Text(gbx.name);

        UI::Separator();

        if ((gbx.type == FileType::Map && gbxMap !is null) || (gbx.type == FileType::Replay && gbxGhost !is null)) {
            if (UI::BeginTable("##table-archive", 2, UI::TableFlags::RowBg)) {
                UI::PushStyleColor(UI::Col::TableRowBgAlt, rowBgAltColor);

                UI::TableSetupColumn("var", UI::TableColumnFlags::WidthFixed, scale * 100.0f);

                if (gbx.type == FileType::Map) {
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("name");
                    UI::TableNextColumn();
                    if (UI::Selectable(Text::StripFormatCodes(gbxMap.MapName), false))
                        IO::SetClipboard(Text::StripFormatCodes(gbxMap.MapName));
                    HoverTooltip(Icons::Clipboard + " Copy");

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("name (color)");
                    UI::TableNextColumn();
                    if (UI::Selectable(gbxMap.MapName, false))
                        IO::SetClipboard(gbxMap.MapName);
                    HoverTooltip(Icons::Clipboard + " Copy");

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("comments");
                    UI::TableNextColumn();
                    if (UI::Selectable(gbxMap.Comments, false))
                        IO::SetClipboard(gbxMap.Comments);
                    HoverTooltip(Icons::Clipboard + " Copy");

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("map UID");
                    UI::TableNextColumn();
                    if (UI::Selectable(gbxMap.EdChallengeId, false))
                        IO::SetClipboard(gbxMap.EdChallengeId);
                    HoverTooltip(Icons::Clipboard + " Copy");

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("author");
                    UI::TableNextColumn();
                    UI::Text(gbxMap.AuthorNickName);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("author zone");
                    UI::TableNextColumn();
                    UI::Text(gbxMap.AuthorZonePath);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("size");
                    UI::TableNextColumn();
                    UI::Text(tostring(gbxMap.Size));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("multilap");
                    UI::TableNextColumn();
                    UI::Text(tostring(gbxMap.TMObjective_IsLapRace));

                    if (gbxMap.TMObjective_IsLapRace) {
                        UI::TableNextRow();
                        UI::TableNextColumn();
                        UI::Text("# laps");
                        UI::TableNextColumn();
                        UI::Text(tostring(gbxMap.TMObjective_NbLaps));
                    }

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("author time");
                    UI::TableNextColumn();
                    UI::Text(Time::Format(gbxMap.TMObjective_AuthorTime != uint(-1) ? gbxMap.TMObjective_AuthorTime : 0));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("gold time");
                    UI::TableNextColumn();
                    UI::Text(Time::Format(gbxMap.TMObjective_GoldTime != uint(-1) ? gbxMap.TMObjective_GoldTime : 0));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("silver time");
                    UI::TableNextColumn();
                    UI::Text(Time::Format(gbxMap.TMObjective_SilverTime != uint(-1) ? gbxMap.TMObjective_SilverTime : 0));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("bronze time");
                    UI::TableNextColumn();
                    UI::Text(Time::Format(gbxMap.TMObjective_BronzeTime != uint(-1) ? gbxMap.TMObjective_BronzeTime : 0));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("custom mod");
                    UI::TableNextColumn();
                    UI::Text(tostring(gbxMap.ModPackDesc !is null));

                    if (gbxMap.ModPackDesc !is null) {
                        UI::TableNextRow();
                        UI::TableNextColumn();
                        UI::Text("mod name");
                        UI::TableNextColumn();
                        if (UI::Selectable(gbxMap.ModPackDesc.Name, false))
                            IO::SetClipboard(gbxMap.ModPackDesc.Name);
                        HoverTooltip(Icons::Clipboard + " Copy");

                        UI::TableNextRow();
                        UI::TableNextColumn();
                        UI::Text("mod URL");
                        UI::TableNextColumn();
                        if (UI::Selectable(gbxMap.ModPackDesc.Url, false))
                            IO::SetClipboard(gbxMap.ModPackDesc.Url);
                        HoverTooltip(Icons::Clipboard + " Copy");
                    }
                } else {
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("map UID");
                    UI::TableNextColumn();
                    UI::Text(gbxGhost.Validate_ChallengeUid.GetName());

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("name");
                    UI::TableNextColumn();
                    UI::Text(gbxGhost.GhostNickname);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("zone");
                    UI::TableNextColumn();
                    UI::Text(gbxGhost.GhostCountryPath);

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("time");
                    UI::TableNextColumn();
                    UI::Text(Time::Format(gbxGhost.RaceTime));

                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("# respawns");
                    UI::TableNextColumn();
                    UI::Text(tostring(gbxGhost.NbRespawns == uint(-1) ? 0 : gbxGhost.NbRespawns));
                }

                UI::PopStyleColor();
                UI::EndTable();
            }
        } else
            UI::Text("\\$FF0GameBox nod is null!");

        if (gbx.type == FileType::Map && gbxMap !is null) {
            UI::BeginDisabled(loading || gbx.root != "user");
                UI::BeginDisabled(!hasPlayPermission || gbxMap.TMObjective_AuthorTime == uint(-1));
                    if (UI::Button(Icons::Play + " Play"))
                        startnew(PlayMap);
                UI::EndDisabled();

                UI::SameLine();
                UI::BeginDisabled(!hasEditPermission);
                    if (UI::Button(Icons::Pencil + " Edit"))
                        startnew(EditMap);
                UI::EndDisabled();
            UI::EndDisabled();
        }
        // not working - can't load from cache folder, replays in user folder aren't cached?
        // else if (gbx.type == FileType::Replay && gbxGhost !is null) {
        //     UI::BeginDisabled(loading);
        //         if (UI::Button(Icons::Pencil + " Edit"))
        //             startnew(EditReplay);
        //     UI::EndDisabled();
        // }

        UI::End();

    if (!gbxWindow)
        @gbx = null;
}

void RenderImagePreview() {
    if (image is null)
        return;

    imageWindow = true;

    UI::Begin(title + " (" + imageExtension + " Image " + uint(imageSize.x) + "x" + uint(imageSize.y) + ")###" + title + "-image", imageWindow, UI::WindowFlags::AlwaysAutoResize);
        UI::Text(imageName);

        UI::Separator();

        if (imageExtension == "DDS") {
            UI::Text("DDS image file not supported");
            UI::Dummy(imageSize);
        } else if (image !is null)
            UI::Image(image, imageSize);
        else {
            UI::Text(imageExtension + " image file not supported");
        }

    UI::End();

    if (!imageWindow)
        @image = null;
}

void RenderTextPreview() {
    if (text.Length == 0)
        return;

    textWindow = true;

    UI::SetNextWindowSize(512, 512);

    UI::Begin(title + " (" + textExtension + " Text)###" + title + "-text", textWindow, UI::WindowFlags::None);
        UI::Text(textName);
        UI::Separator();
        UI::TextWrapped(text);
    UI::End();

    if (!textWindow)
        text = "";
}

void RenderDeleteConfirmation() {
    if (deleteQueued is null)
        return;

    deleteWindow = true;

    bool delete = false;

    UI::Begin(title + " (Delete)", deleteWindow, UI::WindowFlags::AlwaysAutoResize);
        UI::Text(deleteQueued.name);

        UI::Separator();

        UI::Text("Are you sure you want to delete this cached file? \\$F40THIS IS PERMANENT!");

        if (UI::ButtonColored("YES", 0.4f, 1.0f, 0.8f, vec2(scale * 50.0f, scale * 30.0f)))
            delete = true;

        UI::SameLine();
        if (UI::ButtonColored("NO", 0.0f, 1.0f, 0.8f, vec2(scale * 370.0f, scale * 30.0f)))
            deleteWindow = false;
    UI::End();

    if (delete)
        deleteQueued.Delete();

    if (!deleteWindow)
        @deleteQueued = null;
}
