const uint64 maxFrameTime  = 10;
bool         sorting       = false;
uint64       sortLastYield = 0;
SortMethod[] sortMethods   = { SortMethod::LargestFirst };

funcdef int SortFunc(Pack@ p1, Pack@ p2);

int TypeAlpha(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p1.type) - int(p2.type), -1, 1);
}

int SmallestFirst(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p1.size) - int(p2.size), -1, 1);
}

int OldestFirst(Pack@ p1, Pack@ p2) {
    return Math::Clamp(int(p1.lastuseUnix) - int(p2.lastuseUnix), -1, 1);
}

int NameAlpha(Pack@ p1, Pack@ p2) {
    string n1 = p1.name.ToLower();
    string n2 = p2.name.ToLower();

    if (n1 < n2) {
        return -1;
    }
    if (n1 > n2) {
        return 1;
    }
    return 0;
}

enum SortMethod {
    None = 0,
    TypeAlpha = 1,
    TypeAlphaRev = -1,
    SmallestFirst = 2,
    LargestFirst = -2,
    OldestFirst = 3,
    NewestFirst = -3,
    NameAlpha = 4,
    NameAlphaRev = -4,
}

SortFunc@[] sortFunctions = {
    null,
    TypeAlpha,
    SmallestFirst,
    OldestFirst,
    NameAlpha,
};

int multiSort(Pack@ p1, Pack@ p2) {
    int result;
    for (int i = sortMethods.Length - 1; i > -1; i--) {
        if (sortMethods[i] < 0) {
            result = -sortFunctions[-sortMethods[i]](p1, p2);
        } else {
            result = sortFunctions[sortMethods[i]](p1, p2);
        }
        if (result != 0) {
            return result;
        }
    }
    return 0;
}

Pack@[]@ QuickSort(Pack@[]@ arr, int left = 0, int right = -1) {
    uint64 now = Time::Now;
    if (now - sortLastYield > maxFrameTime) {
        sortLastYield = now;
        yield();
    }

    if (right < 0) {
        right = arr.Length - 1;
    }

    if (arr.Length == 0) {
        return arr;
    }

    int i = left;
    int j = right;
    Pack@ pivot = arr[(left + right) / 2];

    while (i <= j) {
        while (multiSort(arr[i], pivot) < 0) {
            i++;
        }

        while (multiSort(arr[j], pivot) > 0) {
            j--;
        }

        if (i <= j) {
            Pack@ temp = arr[i];
            @arr[i] = arr[j];
            @arr[j] = temp;
            i++;
            j--;
        }
    }

    if (left < j) {
        arr = QuickSort(arr, left, j);
    }

    if (i < right) {
        arr = QuickSort(arr, i, right);
    }

    return arr;
}

void SortPacks() {
    while (sorting) {
        yield();
    }

    sorting = true;

    trace("sorting packs...");

    packsSorted.RemoveRange(0, packsSorted.Length);

    for (uint i = 0; i < packs.Length; i++) {
        packsSorted.InsertLast(packs[i]);
    }

    sortLastYield = Time::Now;

    packsSorted = QuickSort(packsSorted);

    trace("sorting packs done!");

    sorting = false;
}
