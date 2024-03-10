// c 2024-03-06
// m 2024-03-09

SQLite::Database@ timeDB = SQLite::Database(":memory:");

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