MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128


def validate_password_strength(value: str) -> str:
    """The single source of truth for password rules. Every schema field
    that accepts a new/changed password (signup today; password-reset and
    change-password later) should call this via a field_validator rather
    than re-implementing the rule.
    """
    if len(value) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters long.")
    if len(value) > MAX_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at most {MAX_PASSWORD_LENGTH} characters long.")
    if not any(char.isdigit() for char in value):
        raise ValueError("Password must contain at least one digit.")
    if not any(char.isalpha() for char in value):
        raise ValueError("Password must contain at least one letter.")
    return value
