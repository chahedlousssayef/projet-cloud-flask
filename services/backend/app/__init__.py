import os
from flask import Flask
from flask_cors import CORS

def create_app():
    app = Flask(__name__, template_folder=os.path.join(os.path.dirname(__file__), "templates"))
    app.config.from_prefixed_env()
    CORS(app)
    from .routes import register_routes
    register_routes(app)
    from .db import init_db
    init_db(app)
    return app

app = create_app()
