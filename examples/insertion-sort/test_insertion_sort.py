"""Tests for insertion_sort. Run with: python test_insertion_sort.py"""

from insertion_sort import insertion_sort


def test_empty_list():
    assert insertion_sort([]) == []


def test_single_element():
    assert insertion_sort([42]) == [42]


def test_already_sorted():
    assert insertion_sort([1, 2, 3, 4, 5]) == [1, 2, 3, 4, 5]


def test_reverse_sorted():
    assert insertion_sort([5, 4, 3, 2, 1]) == [1, 2, 3, 4, 5]


def test_unsorted():
    assert insertion_sort([3, 1, 4, 1, 5, 9, 2, 6]) == [1, 1, 2, 3, 4, 5, 6, 9]


def test_duplicates():
    assert insertion_sort([2, 2, 2, 1, 1]) == [1, 1, 2, 2, 2]


def test_negative_numbers():
    assert insertion_sort([3, -1, 0, -7, 2]) == [-7, -1, 0, 2, 3]


def test_does_not_mutate_input():
    original = [3, 1, 2]
    insertion_sort(original)
    assert original == [3, 1, 2]


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in tests:
        t()
        print("PASS:", t.__name__)
    print("\nAll %d tests passed." % len(tests))
