import urllib.request
import json
import ssl
import sys
import zipfile
import io

def download_failure_log():
    # 1. Fetch latest artifacts in the repository
    url = "https://api.github.com/repos/mataeg/ansible/actions/artifacts"
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(url, headers=headers)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        print("Fetching artifacts list...")
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode("utf-8"))
            artifacts = data.get("artifacts", [])
            
        # Find the one named "build-failure-log"
        target = None
        for art in artifacts:
            if art.get("name") == "build-failure-log":
                target = art
                break
                
        if not target:
            print("No build-failure-log artifact found!")
            return
            
        print(f"Found artifact! ID: {target.get('id')}, Size: {target.get('size_in_bytes')} bytes")
        download_url = target.get("archive_download_url")
        print(f"Download URL: {download_url}")
        
        # We need to download it. GitHub Actions download redirects.
        # Note: Downloading artifacts via API redirects to a pre-signed URL which does not require authentication!
        # But the initial request to archive_download_url DOES require a token if not public.
        # Wait, if it requires a token, let's try to request it.
        # What if we get a 401/403?
        # Let's try downloading it directly.
        req_download = urllib.request.Request(download_url, headers=headers)
        with urllib.request.urlopen(req_download, context=ctx) as dl_res:
            zip_data = dl_res.read()
            
        print("Extracting build_log.txt...")
        with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
            content = z.read("build_log.txt").decode("utf-8")
            
        print("\n=== BUILD LOG CONTENT ===")
        print(content)
        print("=========================")
        
    except Exception as e:
        print(f"Error: {e}")
        print("Since download via API might require auth token, let's try reading the logs of the run from run summary page if possible.")

if __name__ == "__main__":
    download_failure_log()
