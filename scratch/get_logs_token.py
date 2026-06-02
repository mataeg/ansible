import urllib.request
import json
import ssl
import sys
import zipfile
import io

def download_run_logs_with_token(run_id, token):
    url = f"https://api.github.com/repos/mataeg/ansible/actions/runs/{run_id}/logs"
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json"
    }
    req = urllib.request.Request(url, headers=headers)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        print(f"Downloading logs for run {run_id} using token...")
        with urllib.request.urlopen(req, context=ctx) as response:
            zip_data = response.read()
            
        print("Extracting logs...")
        with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
            for filename in z.namelist():
                if "build" in filename.lower() and filename.endswith(".txt"):
                    content = z.read(filename).decode("utf-8")
                    lines = content.splitlines()
                    
                    print(f"\n--- File: {filename} (Total lines: {len(lines)}) ---")
                    
                    # Search for standard flutter compile errors
                    # Let's print the last 150 lines since we did 'cat build_log.txt' on failure,
                    # so the exact compilation errors will be printed at the very end of the build step logs!
                    print("\nLast 150 lines of this log:")
                    for line in lines[-150:]:
                        print(line)
                        
    except Exception as e:
        print(f"Error getting logs: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        download_run_logs_with_token(sys.argv[1], sys.argv[2])
    else:
        print("Please provide a run ID and a token.")
