from example.greet import greet


def test_greet_default() -> None:
    assert greet("world") == "hello, world"


def test_greet_with_name() -> None:
    assert greet("orion") == "hello, orion"


def test_greet_handles_empty_string() -> None:
    assert greet("") == "hello, "
