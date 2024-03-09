// c 2024-03-06
// m 2024-03-08

SQLite::Database@ timeDB = SQLite::Database(":memory:");

string GetSizeMB(uint size, uint precision = 1) {
    return Text::Format("%." + precision + "f", float(size) / 1048576.0f) + " MB";
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