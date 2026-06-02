import urllib.request
import json
import ssl
import sys
import zipfile
import io

def download_run_logs(run_id):
    url = f"https://api.github.com/repos/mataeg/ansible/actions/runs/{run_id}/logs"
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(url, headers=headers)
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        print(f"Downloading logs for run {run_id}...")
        with urllib.request.urlopen(req, context=ctx) as response:
            zip_data = response.read()
            
        print("Extracting logs...")
        with zipfile.ZipFile(io.BytesIO(zip_data)) as z:
            # List files
            for filename in z.namelist():
                # We are looking for the step logs of build or apk build
                # Job is "build", the log file is usually formatted as "job_name/step_number_step_name.txt"
                if "build" in filename.lower() and filename.endswith(".txt"):
                    content = z.read(filename).decode("utf-8")
                    lines = content.splitlines()
                    
                    # Print the lines containing errors or the last 100 lines
                    has_error = False
                    error_lines = []
                    for line in lines:
                        if "error" in line.lower() or "failed" in line.lower() or "exception" in line.lower() or "failure" in line.lower():
                            error_lines.append(line)
                            
                    print(f"\n--- File: {filename} (Total lines: {len(lines)}) ---")
                    if error_lines:
                        print("Found potential error lines:")
                        # Print last 30 error lines
                        for err in error_lines[-30:]:
                            print("  ", err)
                    
                    print("\nLast 50 lines of this log:")
                    for line in lines[-50:]:
                        print("  ", line)
                        
    except Exception as e:
        print(f"Error getting logs: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        download_run_logs(sys.argv[1])
    else:
        print("Please provide a run ID.")
