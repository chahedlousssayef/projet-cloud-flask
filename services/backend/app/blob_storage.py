import os
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import ContentSettings

def get_blob_client():
    conn_str = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    container_name = os.environ.get("AZURE_STORAGE_CONTAINER_NAME", "flask-files")
    if not conn_str:
        return None, None
    client = BlobServiceClient.from_connection_string(conn_str)
    container = client.get_container_client(container_name)
    return client, container

def upload_file(container, file_data, blob_name: str, content_type: str = None):
    blob = container.get_blob_client(blob_name)
    opts = {"overwrite": True}
    if content_type:
        opts["content_settings"] = ContentSettings(content_type=content_type)
    blob.upload_blob(file_data, **opts)
    return blob_name

def download_file(container, blob_name: str) -> bytes:
    blob = container.get_blob_client(blob_name)
    return blob.download_blob().readall()

def delete_file(container, blob_name: str):
    blob = container.get_blob_client(blob_name)
    blob.delete_blob()

def list_blobs(container, prefix: str = ""):
    return [b.name for b in container.list_blobs(name_starts_with=prefix)]
