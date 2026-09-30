from app import Settings, create_app


def client():
    return create_app(Settings(database_url=None)).test_client()


def test_home_page():
    response = client().get("/")
    assert response.status_code == 200
    assert b"Three-Tier AWS Application" in response.data


def test_health_endpoint_is_public_and_safe():
    response = client().get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "ok"


def test_info_does_not_expose_database_url():
    response = client().get("/api/info")
    assert response.status_code == 200
    assert "database_url" not in response.json


def test_visitor_validation():
    response = client().post("/api/visitors", json={"name": ""})
    assert response.status_code == 400


def test_database_health_fails_without_configuration():
    response = client().get("/health/db")
    assert response.status_code == 503
    assert response.json["status"] == "unavailable"
