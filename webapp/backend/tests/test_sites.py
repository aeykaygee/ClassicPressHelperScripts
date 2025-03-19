import pytest
from fastapi import status
from app.models.site import SiteStatus

def get_auth_headers(client, test_user):
    login_response = client.post(
        "/api/v1/auth/token",
        data={
            "username": test_user.email,
            "password": "testpass123"
        }
    )
    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_create_site(client, test_user):
    headers = get_auth_headers(client, test_user)
    response = client.post(
        "/api/v1/sites/",
        headers=headers,
        json={
            "domain": "new.example.com",
            "title": "New Site",
            "admin_email": "admin@new.example.com",
            "admin_user": "admin"
        }
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["domain"] == "new.example.com"
    assert data["title"] == "New Site"
    assert data["status"] == SiteStatus.PENDING

def test_create_site_unauthorized(client):
    response = client.post(
        "/api/v1/sites/",
        json={
            "domain": "new.example.com",
            "title": "New Site",
            "admin_email": "admin@new.example.com",
            "admin_user": "admin"
        }
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

def test_create_site_existing_domain(client, test_user, test_site):
    headers = get_auth_headers(client, test_user)
    response = client.post(
        "/api/v1/sites/",
        headers=headers,
        json={
            "domain": test_site.domain,
            "title": "Another Site",
            "admin_email": "admin@another.example.com",
            "admin_user": "admin"
        }
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "domain already exists" in response.json()["detail"].lower()

def test_list_sites(client, test_user, test_site):
    headers = get_auth_headers(client, test_user)
    response = client.get("/api/v1/sites/", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) == 1
    assert data[0]["domain"] == test_site.domain
    assert data[0]["title"] == test_site.title

def test_get_site(client, test_user, test_site):
    headers = get_auth_headers(client, test_user)
    response = client.get(f"/api/v1/sites/{test_site.id}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["domain"] == test_site.domain
    assert data["title"] == test_site.title

def test_get_site_not_found(client, test_user):
    headers = get_auth_headers(client, test_user)
    response = client.get("/api/v1/sites/999", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Site not found" in response.json()["detail"]

def test_delete_site(client, test_user, test_site):
    headers = get_auth_headers(client, test_user)
    response = client.delete(f"/api/v1/sites/{test_site.id}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["message"] == "Site deletion started"

    # Verify site status is updated
    get_response = client.get(f"/api/v1/sites/{test_site.id}", headers=headers)
    assert get_response.status_code == status.HTTP_200_OK
    assert get_response.json()["status"] == SiteStatus.DELETED

def test_delete_site_not_found(client, test_user):
    headers = get_auth_headers(client, test_user)
    response = client.delete("/api/v1/sites/999", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Site not found" in response.json()["detail"] 