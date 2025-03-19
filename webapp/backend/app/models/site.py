from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Enum
from sqlalchemy.sql import func
from app.core.database import Base
import enum

class SiteStatus(str, enum.Enum):
    PENDING = "pending"
    INSTALLING = "installing"
    ACTIVE = "active"
    FAILED = "failed"
    DELETED = "deleted"

class Site(Base):
    __tablename__ = "sites"

    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String, unique=True, index=True)
    title = Column(String)
    admin_email = Column(String)
    admin_user = Column(String)
    db_name = Column(String)
    db_user = Column(String)
    db_password = Column(String)
    status = Column(Enum(SiteStatus), default=SiteStatus.PENDING)
    user_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    installation_log = Column(String, nullable=True)
    error_log = Column(String, nullable=True) 