from celery import Celery
from app.core.config import settings
from app.services.site_creator import SiteCreator
from app.models.site import Site
from app.core.database import SessionLocal

celery_app = Celery(
    'classicpress_tasks',
    broker=f'redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}/0',
    backend=f'redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}/1'
)

@celery_app.task
def create_site_task(site_id: int):
    db = SessionLocal()
    try:
        site = db.query(Site).filter(Site.id == site_id).first()
        if not site:
            return False
        
        creator = SiteCreator(db)
        return creator.create_site(site)
    finally:
        db.close()

@celery_app.task
def delete_site_task(site_id: int):
    db = SessionLocal()
    try:
        site = db.query(Site).filter(Site.id == site_id).first()
        if not site:
            return False
        
        # TODO: Implement site deletion logic
        site.status = SiteStatus.DELETED
        db.commit()
        return True
    finally:
        db.close() 