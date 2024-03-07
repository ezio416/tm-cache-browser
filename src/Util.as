// c 2024-03-06
// m 2024-03-06

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