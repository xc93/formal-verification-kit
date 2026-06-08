import pytest

from factorial import factorial


def test_zero():
    assert factorial(0) == 1


def test_one():
    assert factorial(1) == 1


def test_small_values():
    assert factorial(2) == 2
    assert factorial(3) == 6
    assert factorial(4) == 24
    assert factorial(5) == 120


def test_larger_value():
    assert factorial(10) == 3628800


def test_negative_raises():
    with pytest.raises(ValueError):
        factorial(-1)
