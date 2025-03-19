import pytest
from unittest.mock import patch, MagicMock
from app.services.site_creator import SiteCreator
from app.models.site import Site, SiteStatus
from app.core.config import settings

@pytest.fixture
def site_creator(db_session):
    return SiteCreator(db_session)

@pytest.fixture
def mock_subprocess():
    with patch('subprocess.run') as mock_run:
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        yield mock_run

@pytest.fixture
def mock_os():
    with patch('os.makedirs') as mock_makedirs, \
         patch('os.path.join') as mock_join, \
         patch('os.path.exists') as mock_exists:
        mock_join.return_value = "/test/path"
        mock_exists.return_value = False
        yield mock_makedirs, mock_join, mock_exists

def test_create_site_success(site_creator, test_site, mock_subprocess, mock_os):
    # Test successful site creation
    result = site_creator.create_site(test_site)
    
    assert result is True
    assert test_site.status == SiteStatus.ACTIVE
    
    # Verify database operations
    mock_subprocess.assert_called()
    mock_os[0].assert_called()

def test_create_site_failure(site_creator, test_site, mock_subprocess):
    # Simulate a failure in subprocess
    mock_subprocess.return_value.returncode = 1
    mock_subprocess.return_value.stderr = "Database error"
    
    result = site_creator.create_site(test_site)
    
    assert result is False
    assert test_site.status == SiteStatus.FAILED
    assert "Database error" in test_site.error_log

def test_create_database(site_creator, test_site, mock_subprocess):
    site_creator._create_database(test_site)
    
    # Verify database creation commands
    mock_subprocess.assert_called()
    calls = mock_subprocess.call_args_list
    
    assert any(f"CREATE DATABASE IF NOT EXISTS {test_site.db_name}" in str(call) for call in calls)
    assert any(f"CREATE USER IF NOT EXISTS {test_site.db_user}" in str(call) for call in calls)
    assert any(f"GRANT ALL PRIVILEGES ON {test_site.db_name}" in str(call) for call in calls)

def test_configure_nginx(site_creator, test_site, mock_subprocess, mock_os):
    site_creator._configure_nginx(test_site)
    
    # Verify Nginx configuration
    mock_subprocess.assert_called()
    calls = mock_subprocess.call_args_list
    
    assert any("nginx -t" in str(call) for call in calls)
    assert any("systemctl reload nginx" in str(call) for call in calls)

def test_install_classicpress(site_creator, test_site, mock_subprocess, mock_os):
    site_creator._install_classicpress(test_site)
    
    # Verify ClassicPress installation steps
    mock_subprocess.assert_called()
    calls = mock_subprocess.call_args_list
    
    assert any("wget https://www.classicpress.net/latest.zip" in str(call) for call in calls)
    assert any("unzip" in str(call) for call in calls)
    assert any("chown" in str(call) for call in calls)
    assert any("wp core install" in str(call) for call in calls)

def test_install_classicpress_download_failure(site_creator, test_site, mock_subprocess):
    # Simulate download failure
    mock_subprocess.return_value.returncode = 1
    mock_subprocess.return_value.stderr = "Download failed"
    
    with pytest.raises(Exception) as exc_info:
        site_creator._install_classicpress(test_site)
    
    assert "Download failed" in str(exc_info.value)

def test_install_classicpress_wp_cli_failure(site_creator, test_site, mock_subprocess):
    # Simulate WP-CLI installation failure
    mock_subprocess.return_value.returncode = 1
    mock_subprocess.return_value.stderr = "WP-CLI error"
    
    with pytest.raises(Exception) as exc_info:
        site_creator._install_classicpress(test_site)
    
    assert "WP-CLI error" in str(exc_info.value) 