// c 2024-03-06
// m 2024-03-06

string GetSizeMB(uint size, uint precision = 1) {
    return Text::Format("%." + precision + "f", float(size) / 1048576.0f) + "MB";
}