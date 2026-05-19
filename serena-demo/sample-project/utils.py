"""Small helpers used by main.py — kept tiny so Serena's
symbol-overview tool surfaces something interesting on a
fresh project."""


def greet(name: str) -> str:
    return f"Hello, {name}!"


def shout(message: str) -> str:
    return message.upper() + "!"
