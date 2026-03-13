import os
import uuid
from flask import request, jsonify, send_file
from io import BytesIO

from .db import get_conn
from .blob_storage import get_blob_client, upload_file, download_file, delete_file, list_blobs

CLOCK_BLOB_PREFIX = "clock-digits/"

def register_routes(app):
    @app.route("/health")
    def health():
        return jsonify({"status": "ok"})

    @app.route("/")
    def index():
        return jsonify({
            "message": "Flask API - Image Clock + Azure Blob Storage",
            "frontend": "Served by Nginx on port 80",
            "api": "/api",
        })

    # ── Clock digit image routes ─────────────────────────────

    @app.route("/api/clock/digits", methods=["GET"])
    def list_digit_images():
        _, container = get_blob_client()
        if not container:
            return jsonify([])
        blobs = list_blobs(container, prefix=CLOCK_BLOB_PREFIX)
        digits = []
        for b in blobs:
            name = b.replace(CLOCK_BLOB_PREFIX, "").split(".")[0]
            if name.isdigit() and 0 <= int(name) <= 9:
                digits.append({"digit": name, "blob": b})
        return jsonify(digits)

    @app.route("/api/clock/digits/<digit>", methods=["POST"])
    def upload_digit_image(digit):
        if digit not in [str(i) for i in range(10)]:
            return jsonify({"error": "Digit must be 0-9"}), 400
        if "image" not in request.files:
            return jsonify({"error": "No image part"}), 400
        file = request.files["image"]
        if file.filename == "":
            return jsonify({"error": "No selected file"}), 400
        _, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "png"
        blob_name = f"{CLOCK_BLOB_PREFIX}{digit}.{ext}"
        existing = list_blobs(container, prefix=f"{CLOCK_BLOB_PREFIX}{digit}.")
        for old in existing:
            try:
                delete_file(container, old)
            except Exception:
                pass
        content_type = file.content_type or "image/png"
        upload_file(container, file.read(), blob_name, content_type)
        return jsonify({"digit": digit, "blob": blob_name}), 201

    @app.route("/api/clock/digits/<digit>/image", methods=["GET"])
    def get_digit_image(digit):
        if digit not in [str(i) for i in range(10)]:
            return jsonify({"error": "Digit must be 0-9"}), 400
        _, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        blobs = list_blobs(container, prefix=f"{CLOCK_BLOB_PREFIX}{digit}.")
        if not blobs:
            return jsonify({"error": "No image for this digit"}), 404
        blob_name = blobs[0]
        ext = blob_name.rsplit(".", 1)[-1].lower()
        mime_map = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                    "gif": "image/gif", "webp": "image/webp", "svg": "image/svg+xml"}
        mime = mime_map.get(ext, "image/png")
        data = download_file(container, blob_name)
        return send_file(BytesIO(data), mimetype=mime)

    @app.route("/api/clock/digits/<digit>", methods=["DELETE"])
    def delete_digit_image(digit):
        if digit not in [str(i) for i in range(10)]:
            return jsonify({"error": "Digit must be 0-9"}), 400
        _, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        blobs = list_blobs(container, prefix=f"{CLOCK_BLOB_PREFIX}{digit}.")
        for b in blobs:
            try:
                delete_file(container, b)
            except Exception:
                pass
        return "", 204

    # ── API info ─────────────────────────────────────────────

    @app.route("/api")
    def api_index():
        return jsonify({
            "message": "Flask API - CRUD + Azure Blob Storage + Image Clock",
            "endpoints": [
                "GET / (Clock UI)",
                "GET /api/clock/digits",
                "POST /api/clock/digits/<digit>",
                "GET /api/clock/digits/<digit>/image",
                "DELETE /api/clock/digits/<digit>",
                "GET /api/items",
                "POST /api/items",
                "GET /api/items/<id>",
                "PATCH /api/items/<id>",
                "DELETE /api/items/<id>",
                "POST /api/items/<id>/files",
                "GET /api/items/<id>/files/<blob_name>",
                "DELETE /api/items/<id>/files/<blob_name>",
            ],
        })

    @app.route("/api/items", methods=["GET"])
    def list_items():
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, title, description, file_name, blob_path, created_at, updated_at FROM items ORDER BY created_at DESC")
        rows = cur.fetchall()
        cur.close()
        return jsonify([dict(r) for r in rows])

    @app.route("/api/items", methods=["POST"])
    def create_item():
        data = request.get_json() or {}
        title = data.get("title") or "Sans titre"
        description = data.get("description") or ""
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO items (title, description) VALUES (%s, %s) RETURNING id, title, description, file_name, blob_path, created_at, updated_at",
            (title, description),
        )
        row = cur.fetchone()
        conn.commit()
        cur.close()
        return jsonify(dict(row)), 201

    @app.route("/api/items/<int:item_id>", methods=["GET"])
    def get_item(item_id):
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, title, description, file_name, blob_path, created_at, updated_at FROM items WHERE id = %s",
            (item_id,),
        )
        row = cur.fetchone()
        cur.close()
        if not row:
            return jsonify({"error": "Not found"}), 404
        return jsonify(dict(row))

    @app.route("/api/items/<int:item_id>", methods=["PATCH"])
    def update_item(item_id):
        data = request.get_json() or {}
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id FROM items WHERE id = %s", (item_id,))
        if not cur.fetchone():
            cur.close()
            return jsonify({"error": "Not found"}), 404
        title = data.get("title")
        description = data.get("description")
        updates = []
        args = []
        if title is not None:
            updates.append("title = %s")
            args.append(title)
        if description is not None:
            updates.append("description = %s")
            args.append(description)
        if updates:
            updates.append("updated_at = CURRENT_TIMESTAMP")
            args.append(item_id)
            cur.execute(
                "UPDATE items SET " + ", ".join(updates) + " WHERE id = %s RETURNING id, title, description, file_name, blob_path, created_at, updated_at",
                args,
            )
            row = cur.fetchone()
            conn.commit()
            cur.close()
            return jsonify(dict(row))
        cur.execute(
            "SELECT id, title, description, file_name, blob_path, created_at, updated_at FROM items WHERE id = %s",
            (item_id,),
        )
        row = cur.fetchone()
        cur.close()
        return jsonify(dict(row))

    @app.route("/api/items/<int:item_id>", methods=["DELETE"])
    def delete_item(item_id):
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT blob_path FROM items WHERE id = %s", (item_id,))
        row = cur.fetchone()
        if not row:
            cur.close()
            return jsonify({"error": "Not found"}), 404
        blob_path = row["blob_path"]
        _, container = get_blob_client()
        if container and blob_path:
            try:
                delete_file(container, blob_path)
            except Exception:
                pass
        cur.execute("DELETE FROM items WHERE id = %s", (item_id,))
        conn.commit()
        cur.close()
        return "", 204

    @app.route("/api/items/<int:item_id>/files", methods=["POST"])
    def upload_item_file(item_id):
        if "file" not in request.files:
            return jsonify({"error": "No file part"}), 400
        file = request.files["file"]
        if file.filename == "":
            return jsonify({"error": "No selected file"}), 400
        client, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        blob_name = f"items/{item_id}/{uuid.uuid4().hex}_{file.filename}"
        content_type = file.content_type or "application/octet-stream"
        upload_file(container, file.read(), blob_name, content_type)
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "UPDATE items SET file_name = %s, blob_path = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s RETURNING id, title, file_name, blob_path",
            (file.filename, blob_name, item_id),
        )
        row = cur.fetchone()
        conn.commit()
        cur.close()
        return jsonify(dict(row))

    @app.route("/api/items/<int:item_id>/files/<path:blob_name>", methods=["GET"])
    def download_item_file(item_id, blob_name):
        _, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        try:
            data = download_file(container, blob_name)
        except Exception:
            return jsonify({"error": "File not found"}), 404
        return send_file(
            BytesIO(data),
            mimetype="application/octet-stream",
            as_attachment=True,
            download_name=blob_name.split("/")[-1].split("_", 1)[-1] if "_" in blob_name.split("/")[-1] else blob_name.split("/")[-1],
        )

    @app.route("/api/items/<int:item_id>/files/<path:blob_name>", methods=["DELETE"])
    def delete_item_file(item_id, blob_name):
        _, container = get_blob_client()
        if not container:
            return jsonify({"error": "Blob storage not configured"}), 503
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE items SET file_name = NULL, blob_path = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = %s AND blob_path = %s", (item_id, blob_name))
        conn.commit()
        if cur.rowcount == 0:
            cur.close()
            return jsonify({"error": "Not found"}), 404
        try:
            delete_file(container, blob_name)
        except Exception:
            pass
        cur.close()
        return "", 204
