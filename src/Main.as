// c 2024-03-06
// m 2024-03-06

Audio::Sample@ audio;
string         audioExtension;
Audio::Voice@  audioLoaded;
string         audioName;
bool           audioWindow   = false;
string         cachePath;
uint           cacheUsage    = 0;
string         checksumFile;
bool           developer     = false;
bool           dirty         = false;
UI::Texture@   image;
string         imageExtension;
string         imageName;
vec2           imageSize     = vec2(0.0f, 0.0f);
bool           imageWindow   = false;
Pack@[]        packs;
Pack@[]        packsSorted;
string         programDataPath;
bool           reading       = false;
const vec4     rowBgAltColor = vec4(0.0f, 0.0f, 0.0f, 0.5f);
const float    scale         = UI::GetScale();
string         search;
uint           searchResults;
string         text;
string         textExtension;
string         textName;
bool           textWindow    = false;
const string   title         = "\\$FF2" + Icons::FolderOpen + "\\$G Cache Browser";

void Main() {
#if SIG_DEVELOPER
    developer = true;
#endif

    programDataPath = string(Fids::GetProgramDataFolder("").FullDirName).Replace("\\", "/");
    cachePath = programDataPath + "Cache/";
    checksumFile = programDataPath + "checksum.txt";
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

    RenderAudioPreview();
    RenderImagePreview();
    RenderTextPreview();
}

void Table_Main() {
    if (UI::BeginTable("##packs-table", developer ? 6 : 5, UI::TableFlags::RowBg | UI::TableFlags::ScrollY | UI::TableFlags::Sortable)) {
        UI::PushStyleColor(UI::Col::TableRowBgAlt, rowBgAltColor);

        UI::TableSetupScrollFreeze(0, 1);
        UI::TableSetupColumn("type", UI::TableColumnFlags::WidthFixed, scale * 65.0f);
        UI::TableSetupColumn("size", UI::TableColumnFlags::WidthFixed, scale * 65.0f);
        UI::TableSetupColumn("last use (UTC)", UI::TableColumnFlags::WidthFixed, scale * 120.0f);
        UI::TableSetupColumn("path", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort, scale * 100.0f);
        if (developer)
            UI::TableSetupColumn("nod", UI::TableColumnFlags::WidthFixed | UI::TableColumnFlags::NoSort, scale * 110.0f);
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
                else if (colSpecs[0].ColumnIndex == (developer ? 5 : 4))
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

                UI::TableNextColumn();
                UI::Text(tostring(pack.lastuseIso.SubStr(0, 16)));

                UI::TableNextColumn();
                if (pack.path.Length > 0 && UI::Selectable(Icons::Clipboard + " Copy Path##" + pack.checksum, false))
                    IO::SetClipboard(pack.path);

                if (developer) {
                    UI::TableNextColumn();
                    if (pack.path.Length > 0 && UI::Selectable(Icons::ExternalLink + " Explore Nod##" + pack.checksum, false)) {
                        CSystemFidFile@ fid;

                        if (pack.file.StartsWith("Cache"))
                            @fid = Fids::GetProgramData(pack.file);
                        else
                            @fid = Fids::GetUser(pack.file);

                        CMwNod@ nod = Fids::Preload(fid);
                        if (nod !is null)
                            ExploreNod(nod);
                        else
                            warn("null nod: " + pack.path);
                    }
                }

                UI::TableNextColumn();
                switch (pack.type) {
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