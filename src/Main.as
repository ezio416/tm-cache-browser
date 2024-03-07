// c 2024-03-06
// m 2024-03-06

bool         developer       = false;
const string programDataPath = "C:/ProgramData/Trackmania/";
const string cachePath       = programDataPath + "Cache/";
const string checksumFile    = programDataPath + "checksum.txt";
Pack@[]      packs;
bool         reading         = false;
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
        if (UI::Button(Icons::File + " Read Checksum File (" + packs.Length + " packs)"))
            startnew(ReadChecksumFile);
        UI::EndDisabled();

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Cache Folder"))
            OpenExplorerPath(cachePath);

        UI::SameLine();
        if (UI::Button(Icons::ExternalLinkSquare + " Open Trackmania Folder"))
            OpenExplorerPath(IO::FromUserGameFolder(""));

        if (UI::BeginTable("##packs-table", developer ? 6 : 5, UI::TableFlags::RowBg | UI::TableFlags::ScrollY)) {
            UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.0f, 0.0f, 0.0f, 0.5f));

            UI::TableSetupScrollFreeze(0, 1);
            UI::TableSetupColumn("type",     UI::TableColumnFlags::WidthFixed, scale * 65.0f);
            UI::TableSetupColumn("size",     UI::TableColumnFlags::WidthFixed, scale * 65.0f);
            UI::TableSetupColumn("last use", UI::TableColumnFlags::WidthFixed, scale * 120.0f);
            UI::TableSetupColumn("path",     UI::TableColumnFlags::WidthFixed, scale * 100.0f);
            if (developer)
                UI::TableSetupColumn("nod",  UI::TableColumnFlags::WidthFixed, scale * 110.0f);
            UI::TableSetupColumn("name");
            UI::TableHeadersRow();

            UI::ListClipper clipper(packs.Length);
            while (clipper.Step()) {
                for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                    Pack@ pack = packs[i];

                    UI::TableNextRow();

                    UI::TableNextColumn();
                    UI::Text(pack.type == FileType::Unknown ? "\\$F00Unknown" : tostring(pack.type));

                    UI::TableNextColumn();
                    UI::Text(GetSizeMB(pack.size, 2));

                    UI::TableNextColumn();
                    UI::Text(pack.lastuse);

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

    reading = false;
}