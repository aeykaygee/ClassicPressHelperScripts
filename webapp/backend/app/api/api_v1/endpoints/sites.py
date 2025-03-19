from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models.site import Site, SiteStatus
from app.tasks.site_tasks import create_site_task, delete_site_task
from pydantic import BaseModel
from app.core.config import settings

router = APIRouter()

class SiteCreate(BaseModel):
    domain: str
    title: str
    admin_email: str
    admin_user: str

class SiteResponse(BaseModel):
    id: int
    domain: str
    title: str
    status: SiteStatus
    created_at: str

    class Config:
        from_attributes = True

@router.post("/", response_model=SiteResponse)
async def create_site(
    site_data: SiteCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    # Check user's site limit
    user_sites = db.query(Site).filter(Site.user_id == current_user.id).count()
    if user_sites >= settings.MAX_SITES_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum number of sites reached"
        )

    # Create site record
    site = Site(
        domain=site_data.domain,
        title=site_data.title,
        admin_email=site_data.admin_email,
        admin_user=site_data.admin_user,
        user_id=current_user.id,
        db_name=f"cp_{site_data.domain.replace('.', '_')}",
        db_user=f"cp_{site_data.domain.replace('.', '_')}",
        db_password=generate_password()
    )
    
    db.add(site)
    db.commit()
    db.refresh(site)

    # Start site creation task
    create_site_task.delay(site.id)

    return site

@router.get("/", response_model=List[SiteResponse])
async def list_sites(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    sites = db.query(Site).filter(Site.user_id == current_user.id).all()
    return sites

@router.get("/{site_id}", response_model=SiteResponse)
async def get_site(
    site_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    site = db.query(Site).filter(
        Site.id == site_id,
        Site.user_id == current_user.id
    ).first()
    
    if not site:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Site not found"
        )
    
    return site

@router.delete("/{site_id}")
async def delete_site(
    site_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    site = db.query(Site).filter(
        Site.id == site_id,
        Site.user_id == current_user.id
    ).first()
    
    if not site:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Site not found"
        )
    
    # Start site deletion task
    delete_site_task.delay(site_id)
    
    return {"message": "Site deletion started"} 