import os
from flask import Blueprint, jsonify
from functools import reduce
from v1.routes.gateway import gw
from v1.routes.docs import docs

v1 = Blueprint('v1', 'v1')

@v1.route('/status', methods=['GET'], strict_slashes=False)
def get_status():
    """
    Returns the overall API status
    :return: JSON of endpoint status
    """
    return jsonify({"status": "ok"})

class Register:
    def __init__(self, app):
        app.register_blueprint(v1, url_prefix="/v1")
        app.register_blueprint(gw, url_prefix="/v1/gateway")
        app.register_blueprint(docs, url_prefix="/v1/api-docs")
