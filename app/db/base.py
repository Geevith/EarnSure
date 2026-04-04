from sqlalchemy.orm import DeclarativeBase, declared_attr

class Base(DeclarativeBase):
    """
    Shared declarative base for all ORM models.
    Provides an automatic snake_case __tablename__ derived from class name.
    """

    @declared_attr.directive
    @classmethod
    def __tablename__(cls) -> str:  # noqa: N805
        # Convert CamelCase → snake_case: HexZone → hex_zone
        import re
        name = cls.__name__
        name = re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()
        return name

from app.models import admin, domain