// c 2024-03-06
// m 2024-03-06

const string cachePath    = "C:/ProgramData/Trackmania/Cache";
const string checksumFile = "C:/ProgramData/Trackmania/checksum.txt";
Pack@[]      packs;
bool         reading      = false;
const float  scale        = UI::GetScale();
const string title        = "\\$FF2" + Icons::FolderOpen + "\\$G Cache Browser";

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

void Main() {
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
        if (UI::Button("load checksum file"))
            startnew(ReadChecksumFile);

        if (UI::BeginTable("##packs-table", 6, UI::TableFlags::ScrollY)) {
            UI::TableSetupScrollFreeze(0, 1);
            UI::TableSetupColumn("root", UI::TableColumnFlags::WidthFixed, scale * 50.0f);
            UI::TableSetupColumn("size", UI::TableColumnFlags::WidthFixed, scale * 65.0f);
            UI::TableSetupColumn("lastuse", UI::TableColumnFlags::WidthFixed, scale * 120.0f);
            UI::TableSetupColumn("name");
            UI::TableSetupColumn("file");
            UI::TableSetupColumn("checksum");
            UI::TableHeadersRow();

            UI::ListClipper clipper(packs.Length);
            while (clipper.Step()) {
                for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                    Pack@ pack = packs[i];

                    UI::TableNextRow();
                    UI::TableNextColumn(); UI::Text(pack.root);
                    UI::TableNextColumn(); UI::Text(GetSizeMB(pack.size, 2));
                    UI::TableNextColumn(); UI::Text(pack.lastuse);
                    UI::TableNextColumn(); UI::Text(pack.name);
                    UI::TableNextColumn(); UI::Text(pack.file);
                    UI::TableNextColumn(); UI::Text(pack.checksum);
                }
            }

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

    IO::File file(checksumFile, IO::FileMode::Read);
    string xml = file.ReadToEnd();
    file.Close();

    XML::Document doc(xml);
    XML::Node cache = doc.Root().FirstChild();

    XML::Node node = cache.FirstChild();
    packs.InsertLast(Pack(node));

    while (true) {
        node = node.NextSibling();
        Pack pack(node);
        if (pack.checksum.Length == 0)
            break;
        packs.InsertLast(pack);
        yield();
    }

    trace("reading checksum file done! (" + packs.Length + " packs)");

    reading = false;
}

class Pack {
    string checksum;
    string file;
    string lastuse;
    string name;
    string root;
    uint   size;

    Pack() { }
    Pack(XML::Node node) {
        checksum = node.Child("checksum").Content();
        file     = node.Child("file").Content();
        lastuse  = node.Child("lastuse").Content();
        name     = node.Child("name").Content();
        root     = node.Child("root").Content();
        size     = Text::ParseUInt(node.Child("size").Content());
    }
}

string GetSizeMB(uint size, uint precision = 1) {
    return Text::Format("%." + precision + "f", float(size) / 1048576) + "MB";
}