// c 2024-03-06
// m 2024-03-06

const uint64 maxFrameTime  = 10;
bool         sorting       = false;
uint64       sortLastYield = 0;
SortMethod   sortMethod    = SortMethod::LargestFirst;

funcdef int SortFunc(Pack@ p1, Pack@ p2);

int TypeAlpha(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p1.type) - int(p2.type), -1, 1);
}

int TypeAlphaRev(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p2.type) - int(p1.type), -1, 1);
}

int SmallestFirst(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p1.size) - int(p2.size), -1, 1);
}

int LargestFirst(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p2.size) - int(p1.size), -1, 1);
}

int NameAlpha(Pack@ p1, Pack@ p2) {
    string n1 = p1.name.ToLower();
    string n2 = p2.name.ToLower();

    if (n1 < n2)
        return -1;
    if (n1 > n2)
        return 1;
    return 0;
}

int NameAlphaRev(Pack@ p1, Pack@ p2) {
    string n1 = p1.name.ToLower();
    string n2 = p2.name.ToLower();

    if (n1 < n2)
        return 1;
    if (n1 > n2)
        return -1;
    return 0;
}

enum SortMethod {
    TypeAlpha,
    TypeAlphaRev,
    SmallestFirst,
    LargestFirst,
    NameAlpha,
    NameAlphaRev,
}

SortFunc@[] sortFunctions = {
    TypeAlpha,
    TypeAlphaRev,
    SmallestFirst,
    LargestFirst,
    NameAlpha,
    NameAlphaRev,
};

Pack@[]@ QuickSort(Pack@[]@ arr, SortFunc@ f, int left = 0, int right = -1) {
    uint64 now = Time::Now;
    if (now - sortLastYield > maxFrameTime) {
        sortLastYield = now;
        yield();
    }

    if (right < 0)
        right = arr.Length - 1;

    if (arr.Length == 0)
        return arr;

    int i = left;
    int j = right;
    Pack@ pivot = arr[(left + right) / 2];

    while (i <= j) {
        while (f(arr[i], pivot) < 0)
            i++;

        while (f(arr[j], pivot) > 0)
            j--;

        if (i <= j) {
            Pack@ temp = arr[i];
            @arr[i] = arr[j];
            @arr[j] = temp;
            i++;
            j--;
        }
    }

    if (left < j)
        arr = QuickSort(arr, f, left, j);

    if (i < right)
        arr = QuickSort(arr, f, i, right);

    return arr;
}

void SortPacks() {
    while (sorting)
        yield();

    sorting = true;

    trace("sorting packs...");

    packsSorted.RemoveRange(0, packsSorted.Length);

    for (uint i = 0; i < packs.Length; i++)
        packsSorted.InsertLast(packs[i]);

    sortLastYield = Time::Now;

    packsSorted = QuickSort(packsSorted, sortFunctions[sortMethod]);

    trace("sorting packs done!");

    sorting = false;
}