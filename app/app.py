"""Portfolio Flask application for the three-tier AWS architecture."""

from __future__ import annotations

import logging
import os
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime, timezone

import psycopg
from flask import Flask, jsonify, render_template, request


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "Three-Tier AWS Application")
    environment: str = os.getenv("APP_ENV", "development")
    version: str = os.getenv("APP_VERSION", "local")
    database_url: str | None = os.getenv("DATABASE_URL")


def create_app(settings: Settings | None = None) -> Flask:
    app = Flask(__name__)
    config = settings or Settings()
    app.config["SETTINGS"] = config

    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(message)s")
    logger = logging.getLogger("three-tier-app")

    def get_db_connection():
        if not config.database_url:
            raise RuntimeError("DATABASE_URL is not configured")
        return psycopg.connect(config.database_url, connect_timeout=3)

    @app.get("/")
    def index():
        return render_template("index.html", app_name=config.app_name, environment=config.environment)

    @app.get("/health")
    def health():
        return jsonify(status="ok", service="web", version=config.version)

    @app.get("/health/db")
    def database_health():
        try:
            with closing(get_db_connection()) as connection, connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
            return jsonify(status="ok", service="database")
        except Exception:
            logger.exception("Database health check failed")
            return jsonify(status="unavailable", service="database"), 503

    @app.get("/api/info")
    def info():
        return jsonify(name=config.app_name, environment=config.environment, version=config.version)

    @app.get("/api/visitors")
    def list_visitors():
        try:
            with closing(get_db_connection()) as connection, connection.cursor() as cursor:
                cursor.execute("SELECT id, name, created_at FROM visitors ORDER BY created_at DESC LIMIT 100")
                visitors = [
                    {"id": row[0], "name": row[1], "created_at": row[2].isoformat()}
                    for row in cursor.fetchall()
                ]
            return jsonify(visitors=visitors)
        except Exception:
            logger.exception("Could not retrieve visitors")
            return jsonify(error="Visitor service is temporarily unavailable"), 503

    @app.post("/api/visitors")
    def create_visitor():
        payload = request.get_json(silent=True) or {}
        name = payload.get("name")
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100:
            return jsonify(error="name must be a non-empty string of at most 100 characters"), 400
        try:
            with closing(get_db_connection()) as connection, connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO visitors (name) VALUES (%s) RETURNING id, name, created_at",
                    (name.strip(),),
                )
                visitor = cursor.fetchone()
                connection.commit()
            return jsonify(id=visitor[0], name=visitor[1], created_at=visitor[2].isoformat()), 201
        except Exception:
            logger.exception("Could not create visitor")
            return jsonify(error="Visitor service is temporarily unavailable"), 503

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify(error="Not found"), 404

    @app.context_processor
    def inject_now():
        return {"current_year": datetime.now(timezone.utc).year}

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
