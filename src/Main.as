// c 2024-03-06
// m 2024-03-06

bool         developer       = false;
const string programDataPath = "C:/ProgramData/Trackmania/";
const string cachePath       = programDataPath + "Cache/";
uint         cacheUsage      = 0;
const string checksumFile    = programDataPath + "checksum.txt";
bool         dirty           = false;
Pack@[]      packs;
Pack@[]      packsSorted;
bool         reading         = false;
const vec4   rowBgAltColor   = vec4(0.0f, 0.0f, 0.0f, 0.5f);
const float  scale           = UI::GetScale();
const string title           = "\\$FF2" + Icons::FolderOpen + "\\$G Cache Browser";

void Main() {
#if SIG_DEVELOPER
    developer = true;
#endif
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
        if (UI::Button(Icons::File + " Read Checksum File (" + packsSorted.Length + " Items)"))
            startnew(ReadChecksumFile);
        UI::EndDisabled();

        UI::SameLine();
        if (UI::Button(Icons::Refresh + " Refresh Cache Usage (" + GetSizeMB(cacheUsage) + ")"))
            startnew(ReadCacheUsage);

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Cache Folder"))
            OpenExplorerPath(cachePath);

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Trackmania Folder"))
            OpenExplorerPath(IO::FromUserGameFolder(""));

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

            UI::ListClipper clipper(packsSorted.Length);
            while (clipper.Step()) {
                for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                    Pack@ pack = packsSorted[i];

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
                            CSystemFidFile@ file;

                            if (pack.file.StartsWith("Cache"))
                                @file = Fids::GetProgramData(pack.file);
                            else
                                @file = Fids::GetUser(pack.file);

                            CMwNod@ nod = Fids::Preload(file);
                            ExploreNod(nod);
                        }
                    }

                    UI::TableNextColumn();
                    UI::Text(pack.name);
                }
            }

            UI::PopStyleColor();
            UI::EndTable();
        }

    UI::End();
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